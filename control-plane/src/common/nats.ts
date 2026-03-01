import {
  AckPolicy,
  type ConnectionOptions,
  DeliverPolicy,
  ReplayPolicy,
  RetentionPolicy,
  StringCodec,
  connect,
  type Consumer,
  type NatsConnection
} from 'nats';

const sc = StringCodec();

export async function connectNats(servers: string): Promise<NatsConnection> {
  const options: ConnectionOptions = {
    servers: []
  };

  options.servers = servers
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v.length > 0)
    .map((raw) => {
      const url = new URL(raw.includes('://') ? raw : `nats://${raw}`);

      if (url.username && options.user === undefined) {
        options.user = decodeURIComponent(url.username);
      }
      if (url.password && options.pass === undefined) {
        options.pass = decodeURIComponent(url.password);
      }

      url.username = '';
      url.password = '';

      return `${url.protocol}//${url.host}`;
    });

  return connect(options);
}

export async function ensureStream(nc: NatsConnection, streamName: string): Promise<void> {
  const jsm = await nc.jetstreamManager();

  try {
    await jsm.streams.info(streamName);
  } catch {
    await jsm.streams.add({
      name: streamName,
      subjects: ['tasks.>', 'results.>', 'control.>'],
      retention: RetentionPolicy.Limits,
      max_age: 7 * 24 * 60 * 60 * 1_000_000_000
    });
  }
}

export async function ensureConsumer(
  nc: NatsConnection,
  streamName: string,
  durableName: string,
  filterSubject: string
): Promise<Consumer> {
  const jsm = await nc.jetstreamManager();

  try {
    await jsm.consumers.info(streamName, durableName);
  } catch {
    await jsm.consumers.add(streamName, {
      durable_name: durableName,
      ack_policy: AckPolicy.Explicit,
      deliver_policy: DeliverPolicy.All,
      filter_subject: filterSubject,
      max_ack_pending: 200,
      replay_policy: ReplayPolicy.Instant
    });
  }

  const js = nc.jetstream();
  return js.consumers.get(streamName, durableName);
}

export function encodeJson(payload: unknown): Uint8Array {
  return sc.encode(JSON.stringify(payload));
}

export function decodeJson<T>(payload: Uint8Array): T {
  return JSON.parse(sc.decode(payload)) as T;
}
