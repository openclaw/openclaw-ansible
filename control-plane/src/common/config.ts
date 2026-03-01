export interface AppConfig {
  serviceName: string;
  profile: string;
  natsUrl: string;
  natsStream: string;
  metricsPort: number;
  pgUrl: string;
  telegramBotToken: string;
  telegramDefaultChatId: string;
  routerForcedAgent: string;
  workerAgentId: string;
  workerExecMode: string;
  openclawBin: string;
  openclawHome: string;
  openclawEnvFile: string;
  openclawGatewayToken: string;
  openclawTimeoutMs: number;
  openclawBundledPluginsDir: string;
}

function intFromEnv(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

export function loadConfig(serviceName: string): AppConfig {
  return {
    serviceName,
    profile: process.env.OPENCLAW_PROFILE ?? 'efra-core',
    natsUrl: process.env.NATS_URL ?? 'nats://nats:4222',
    natsStream: process.env.NATS_STREAM ?? 'OPENCLAW_TASKS',
    metricsPort: intFromEnv('METRICS_PORT', 9400),
    pgUrl: process.env.POSTGRES_URL ?? 'postgres://openclaw:openclaw@postgres:5432/openclaw_control',
    telegramBotToken: process.env.TELEGRAM_BOT_TOKEN ?? '',
    telegramDefaultChatId: process.env.TELEGRAM_DEFAULT_CHAT_ID ?? '',
    routerForcedAgent: process.env.ROUTER_FORCED_AGENT ?? '',
    workerAgentId: process.env.WORKER_AGENT_ID ?? 'main',
    workerExecMode: process.env.WORKER_EXEC_MODE ?? 'stub',
    openclawBin: process.env.OPENCLAW_BIN ?? '/home/openclaw/.local/bin/openclaw',
    openclawHome: process.env.OPENCLAW_HOME ?? '/home/openclaw',
    openclawEnvFile: process.env.OPENCLAW_ENV_FILE ?? `/etc/openclaw/secrets/${process.env.OPENCLAW_PROFILE ?? 'dev-main'}.env`,
    openclawGatewayToken: process.env.OPENCLAW_GATEWAY_TOKEN ?? '',
    openclawTimeoutMs: intFromEnv('OPENCLAW_TIMEOUT_MS', 120000),
    openclawBundledPluginsDir:
      process.env.OPENCLAW_BUNDLED_PLUGINS_DIR ?? '/home/openclaw/.openclaw/bundled-extensions'
  };
}
