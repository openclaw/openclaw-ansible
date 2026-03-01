import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { ConsumerMessages, NatsConnection } from 'nats';

import { loadConfig } from '../common/config';
import { type TaskEnvelope, type TaskResult } from '../common/contracts';
import { actionNeedsConfirmation } from '../common/intents';
import { type ServiceMetrics, initMetrics, startMetricsServer } from '../common/metrics';
import { connectNats, decodeJson, encodeJson, ensureConsumer, ensureStream } from '../common/nats';

const execFileAsync = promisify(execFile);

@Injectable()
export class WorkerRunner implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(WorkerRunner.name);
  private readonly cfg = loadConfig('worker');
  private nc: NatsConnection | null = null;
  private messages: ConsumerMessages | null = null;
  private metrics: ServiceMetrics | null = null;
  private metricsServer: ReturnType<typeof startMetricsServer> | null = null;

  async onModuleInit(): Promise<void> {
    this.metrics = initMetrics(`worker_${this.cfg.workerAgentId.replace('-', '_')}`);
    this.metricsServer = startMetricsServer(this.cfg.metricsPort, this.metrics.registry);

    this.nc = await connectNats(this.cfg.natsUrl);
    await ensureStream(this.nc, this.cfg.natsStream);

    const durable = `${this.cfg.profile}-worker-${this.cfg.workerAgentId}`;
    const filter = `tasks.agent.${this.cfg.workerAgentId}`;
    const consumer = await ensureConsumer(this.nc, this.cfg.natsStream, durable, filter);
    this.messages = await consumer.consume();

    this.run().catch((error: unknown) => this.logger.error(`Worker loop failed: ${String(error)}`));

    this.logger.log(`Worker ${this.cfg.workerAgentId} online`);
  }

  async onModuleDestroy(): Promise<void> {
    this.messages?.close();
    await this.nc?.drain();
    this.metricsServer?.close();
  }

  private async run(): Promise<void> {
    if (!this.messages || !this.nc) {
      throw new Error('Worker is not initialized');
    }

    for await (const msg of this.messages) {
      try {
        const task = decodeJson<TaskEnvelope>(msg.data);
        const result = await this.processTask(task);
        this.nc.publish(`results.agent.${this.cfg.workerAgentId}`, encodeJson(result));
        this.metrics?.handledMessages.inc();
        msg.ack();
      } catch (error) {
        this.metrics?.failedMessages.inc();
        msg.nak();
        this.logger.error(`Failed task processing: ${String(error)}`);
      }
    }
  }

  private async processTask(task: TaskEnvelope): Promise<TaskResult> {
    const needsConfirmation = actionNeedsConfirmation(task.text);

    if (needsConfirmation) {
      return {
        taskId: task.taskId,
        profile: task.profile,
        fromAgent: this.cfg.workerAgentId,
        status: 'WAITING_CONFIRMATION',
        summary: `Task ${task.taskId} routed to ${this.cfg.workerAgentId}`,
        fullResponse: `Action requires confirmation before execution: ${task.text}`,
        needsConfirmation: true,
        suggestedAction: `confirmar ${task.taskId}`,
        tokenUsage: Math.min(300, task.text.length * 2),
        costEstimate: 0,
        source: task.source,
        createdAt: new Date().toISOString()
      };
    }

    if (this.cfg.workerExecMode === 'openclaw') {
      return this.processWithOpenClaw(task);
    }

    return {
      taskId: task.taskId,
      profile: task.profile,
      fromAgent: this.cfg.workerAgentId,
      status: 'DONE',
      summary: `Task ${task.taskId} routed to ${this.cfg.workerAgentId}`,
      fullResponse: `Processed by ${this.cfg.workerAgentId}: ${task.text}`,
      needsConfirmation: false,
      tokenUsage: Math.min(300, task.text.length * 2),
      costEstimate: 0,
      source: task.source,
      createdAt: new Date().toISOString()
    };
  }

  private async processWithOpenClaw(task: TaskEnvelope): Promise<TaskResult> {
    const env = {
      ...process.env,
      HOME: this.cfg.openclawHome,
      OPENCLAW_HOME: this.cfg.openclawHome,
      OPENCLAW_GATEWAY_TOKEN: this.cfg.openclawGatewayToken,
      OPENCLAW_BUNDLED_PLUGINS_DIR: this.cfg.openclawBundledPluginsDir
    };

    try {
      const { stdout } = await execFileAsync(
        this.cfg.openclawBin,
        [
          '--profile',
          this.cfg.profile,
          'agent',
          '--agent',
          this.cfg.workerAgentId,
          '--message',
          task.text,
          '--json'
        ],
        {
          env,
          timeout: this.cfg.openclawTimeoutMs,
          maxBuffer: 1024 * 1024
        }
      );

      const parsed = this.extractJson(stdout) as Record<string, any>;
      const payloads = Array.isArray(parsed?.payloads)
        ? parsed.payloads
        : Array.isArray(parsed?.result?.payloads)
          ? parsed.result.payloads
          : [];
      const text = payloads
        .map((item: { text?: string } | undefined) => item?.text ?? '')
        .filter((line: string) => line.trim().length > 0)
        .join('\n')
        .trim();

      const meta = parsed?.meta ?? parsed?.result?.meta ?? {};
      const totalTokens = Number(meta?.agentMeta?.usage?.total ?? 0);

      return {
        taskId: task.taskId,
        profile: task.profile,
        fromAgent: this.cfg.workerAgentId,
        status: 'DONE',
        summary: `Task ${task.taskId} handled by OpenClaw agent ${this.cfg.workerAgentId}`,
        fullResponse: text || `Agent ${this.cfg.workerAgentId} completed with empty text payload.`,
        needsConfirmation: false,
        tokenUsage: Number.isFinite(totalTokens) && totalTokens > 0 ? totalTokens : undefined,
        costEstimate: 0,
        source: task.source,
        createdAt: new Date().toISOString()
      };
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      this.logger.warn(`OpenClaw exec failed for ${task.taskId}: ${detail}`);

      return {
        taskId: task.taskId,
        profile: task.profile,
        fromAgent: this.cfg.workerAgentId,
        status: 'FAILED',
        summary: `Task ${task.taskId} failed in OpenClaw agent ${this.cfg.workerAgentId}`,
        fullResponse: `Agent execution failed: ${detail}`,
        needsConfirmation: false,
        costEstimate: 0,
        source: task.source,
        createdAt: new Date().toISOString()
      };
    }
  }

  private extractJson(stdout: string): Record<string, unknown> {
    const trimmed = stdout.trim();
    if (!trimmed) {
      return {};
    }

    try {
      return JSON.parse(trimmed) as Record<string, unknown>;
    } catch {
      const start = trimmed.indexOf('{');
      const end = trimmed.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return JSON.parse(trimmed.slice(start, end + 1)) as Record<string, unknown>;
      }
      throw new Error('openclaw returned non-JSON output');
    }
  }
}
