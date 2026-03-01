---
title: Stage 2 Control Plane (NATS + NestJS)
summary: Full/lite queue orchestration package installable per profile
---

# Stage 2 Control Plane

This repository now includes a reusable Stage 2 package for queue orchestration and telemetry.

## Modes

- `full` (`efra-core`): complete stack
  - NATS JetStream
  - PostgreSQL state store
  - NestJS services: `ingress`, `router`, `broker`, `worker-main`, `worker-research`, `worker-browser-login`, `worker-coolify-ops`, `control-api`
  - Observability: Prometheus + Grafana + Uptime Kuma
- `lite` (`andrea`): minimal direct worker path
  - NATS JetStream
  - PostgreSQL state store
  - NestJS services: `ingress`, `router` (forced to `main`), `worker-main`, `broker`, `control-api`

## Intent Routing

Ingress receives Telegram/API messages and publishes `tasks.ingress`.
Router classifies intent and emits `tasks.agent.<agent>`.
Workers consume per-agent queues and emit `results.agent.<agent>`.
Broker persists outputs and can send Telegram replies.

Ingress also supports a direct Telegram command:

- `/agents` (or `/agents@<bot>`) to list available agents and intent mappings without queueing a task.

## Contract

Task envelope fields:
- `taskId`
- `profile`
- `source.channel/chatId/userId`
- `text`
- `intent`
- `targetAgent`
- `status`

Result envelope fields:
- `taskId`
- `fromAgent`
- `status`
- `summary`
- `fullResponse`
- `needsConfirmation`

## Deployment

Enabled through `playbooks/enterprise.yml` with role `openclaw_control_plane`.

Inventory variables (`inventories/<env>/group_vars/all.yml`):
- `openclaw_control_plane_enabled`
- `openclaw_control_plane_profiles`

Secrets (`inventories/<env>/group_vars/vault.yml`):
- `vault_openclaw_cp_postgres_password_*`
- `vault_openclaw_cp_nats_password_*`
- `vault_telegram_bot_token_*`
- `vault_telegram_default_chat_id_*`

## Operational Endpoints

- Ingress: `http://127.0.0.1:<ingress_port>/telegram/webhook`
- Control API: `http://127.0.0.1:<control_api_port>/tasks`
- Queue stats: `http://127.0.0.1:<control_api_port>/queues`
- Grafana (`full` only): `http://127.0.0.1:<grafana_port>`
- Prometheus (`full` only): `http://127.0.0.1:<prometheus_port>`

You can publish these loopback endpoints through Cloudflare Tunnel subdomains by enabling
`openclaw_cloudflare_tunnel_*` variables in inventory (see `docs/cloudflare-tunnel.md`).

## Packaging for other profiles

To install this package on another profile, add one object to `openclaw_control_plane_profiles`.
No code changes are required, only profile variables and secrets.

## Browser worker networking (full mode)

For browser-driven flows (`browser-login`) the full stack template uses:

- `network_mode: host`
- `shm_size: "1gb"`
- worker-local `NATS_URL` override to `127.0.0.1:<nats_host_port>`

This keeps queue consumption stable while allowing browser-related operations to reach host-local gateway/browser relay paths.
