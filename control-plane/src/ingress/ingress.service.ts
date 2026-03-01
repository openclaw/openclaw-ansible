import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { NatsConnection } from 'nats';

import { type AppConfig, loadConfig } from '../common/config';
import { type TaskEnvelope } from '../common/contracts';
import { listAvailableAgents } from '../common/intents';
import { connectNats, encodeJson, ensureStream } from '../common/nats';

interface TelegramUpdate {
  message?: {
    text?: string;
    chat?: { id?: number | string };
    from?: { id?: number | string; username?: string };
  };
}

@Injectable()
export class IngressService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(IngressService.name);
  private readonly cfg: AppConfig = loadConfig('ingress');
  private nc: NatsConnection | null = null;

  async onModuleInit(): Promise<void> {
    this.nc = await connectNats(this.cfg.natsUrl);
    await ensureStream(this.nc, this.cfg.natsStream);
    this.logger.log(`Connected to NATS at ${this.cfg.natsUrl}`);
  }

  async onModuleDestroy(): Promise<void> {
    await this.nc?.drain();
  }

  async ingestTelegram(body: TelegramUpdate): Promise<{ taskId: string }> {
    if (!this.nc) {
      throw new Error('NATS is not ready');
    }

    const text = body.message?.text?.trim() ?? '';
    const chatId = body.message?.chat?.id ? String(body.message.chat.id) : this.cfg.telegramDefaultChatId;
    const userId = body.message?.from?.id ? String(body.message.from.id) : undefined;
    const username = body.message?.from?.username;

    if (!text) {
      throw new Error('Message text is required');
    }

    if (await this.tryHandleTelegramCommand(text, chatId)) {
      return { taskId: `cmd-${randomUUID()}` };
    }

    const task: TaskEnvelope = {
      taskId: randomUUID(),
      profile: this.cfg.profile,
      source: {
        channel: 'telegram',
        chatId,
        userId,
        username
      },
      text,
      status: 'NEW',
      priority: 5,
      budgetTokens: 4000,
      createdAt: new Date().toISOString()
    };

    this.nc.publish('tasks.ingress', encodeJson(task));
    this.logger.log(`Queued task ${task.taskId} for ingress`);

    return { taskId: task.taskId };
  }

  private async tryHandleTelegramCommand(text: string, chatId: string): Promise<boolean> {
    if (!this.isAgentsCommand(text)) {
      return false;
    }

    if (!this.cfg.telegramBotToken || !chatId) {
      return false;
    }

    const agents = listAvailableAgents();
    const lines = [
      `Available agents (${this.cfg.profile}):`,
      ...agents.map((agent) => `- ${agent.id}: ${agent.description} [${agent.intent}]`),
      '',
      'Usage: send a normal request and the router will select the target by intent.'
    ];

    await this.sendTelegramMessage(chatId, lines.join('\n'));
    return true;
  }

  private isAgentsCommand(text: string): boolean {
    const firstToken = text.trim().split(/\s+/)[0]?.toLowerCase() ?? '';
    return firstToken === '/agents' || firstToken.startsWith('/agents@');
  }

  private async sendTelegramMessage(chatId: string, text: string): Promise<void> {
    const response = await fetch(
      `https://api.telegram.org/bot${this.cfg.telegramBotToken}/sendMessage`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text
        })
      }
    );

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Telegram send failed: ${response.status} ${body}`);
    }
  }
}
