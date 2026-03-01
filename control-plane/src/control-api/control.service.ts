import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import type { NatsConnection } from 'nats';
import type { Pool } from 'pg';

import { type ConfirmationCommand, type QueueStats } from '../common/contracts';
import { loadConfig } from '../common/config';
import { connectNats, encodeJson } from '../common/nats';
import { createPgPool, migrate } from '../common/postgres';

@Injectable()
export class ControlService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ControlService.name);
  private readonly cfg = loadConfig('control_api');
  private pg: Pool | null = null;
  private nc: NatsConnection | null = null;

  async onModuleInit(): Promise<void> {
    this.pg = createPgPool(this.cfg.pgUrl);
    await migrate(this.pg);

    this.nc = await connectNats(this.cfg.natsUrl);
    this.logger.log('Control API ready');
  }

  async onModuleDestroy(): Promise<void> {
    await this.nc?.drain();
    await this.pg?.end();
  }

  async listTasks(limit = 100): Promise<unknown[]> {
    const safeLimit = Math.max(1, Math.min(limit, 500));
    const result = await this.pg?.query(
      `SELECT task_id, profile, source_channel, chat_id, user_id, target_agent, status, needs_confirmation, summary, updated_at
       FROM tasks
       ORDER BY updated_at DESC
       LIMIT $1`,
      [safeLimit]
    );

    return result?.rows ?? [];
  }

  async getTask(taskId: string): Promise<unknown> {
    const result = await this.pg?.query(
      `SELECT task_id, profile, source_channel, chat_id, user_id, target_agent, status, needs_confirmation, summary, result_payload, updated_at
       FROM tasks
       WHERE task_id = $1`,
      [taskId]
    );

    return result?.rows?.[0] ?? null;
  }

  async setDecision(taskId: string, decision: 'confirm' | 'reject', actor: string, note?: string): Promise<void> {
    const command: ConfirmationCommand = {
      taskId,
      profile: this.cfg.profile,
      decision,
      note,
      actor,
      createdAt: new Date().toISOString()
    };

    const nextStatus = decision === 'confirm' ? 'DONE' : 'FAILED';

    const updated = await this.pg?.query(
      `
      UPDATE tasks
      SET status = $1,
          needs_confirmation = FALSE,
          updated_at = NOW()
      WHERE task_id = $2
        AND profile = $3
        AND needs_confirmation = TRUE
      `,
      [nextStatus, taskId, this.cfg.profile]
    );

    if ((updated?.rowCount ?? 0) === 0) {
      this.logger.warn(`Decision ${decision} for task ${taskId} did not match a pending confirmation row`);
    }

    this.nc?.publish(`control.${decision}.${this.cfg.profile}`, encodeJson(command));

    await this.pg?.query(
      `
      INSERT INTO task_events (task_id, profile, event_type, from_agent, payload)
      VALUES ($1, $2, $3, $4, $5::jsonb)
      `,
      [taskId, this.cfg.profile, `decision_${decision}`, actor, JSON.stringify({ ...command, status: nextStatus })]
    );
  }

  async queueStats(): Promise<QueueStats | null> {
    if (!this.nc) {
      return null;
    }

    const jsm = await this.nc.jetstreamManager();
    const info = await jsm.streams.info(this.cfg.natsStream);

    return {
      stream: info.config.name,
      messages: info.state.messages,
      bytes: info.state.bytes,
      firstSeq: info.state.first_seq,
      lastSeq: info.state.last_seq
    };
  }
}
