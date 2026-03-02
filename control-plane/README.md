# ClawOps Stage 2 Control Plane

Control-plane de la suite operativa: microservicios NestJS + NATS JetStream para ruteo multi-agente, persistencia de estados y control de ejecución.

## Servicios

- `ingress`: recibe tráfico Telegram/API y publica `tasks.ingress`.
- `router`: clasifica y enruta a `tasks.agent.<agent>`.
- `worker`: consume por agente y publica `results.agent.<agent>`.
- `broker`: persiste resultados/eventos y puede responder a Telegram.
- `control-api`: consulta tareas, cola y decisiones (`confirm/reject`).

## Qué Falencia Resuelve

1. Falta de bus/eventos para tareas multi-agente.
2. Falta de estado persistente de ejecución.
3. Falta de API de control para operaciones y confirmaciones.
4. Falta de trazabilidad de eventos por tarea.

## Contrato de Mensajes

### Task envelope

- `taskId`
- `profile`
- `source.channel/chatId/userId`
- `text`
- `intent`
- `targetAgent`
- `status`

### Result envelope

- `taskId`
- `profile`
- `fromAgent`
- `status`
- `summary`
- `fullResponse`
- `needsConfirmation`

## Ejecución Local

```bash
pnpm install
pnpm run build
pnpm run start:ingress
pnpm run start:router
pnpm run start:worker
pnpm run start:broker
pnpm run start:control-api
```

## Variables de Entorno Relevantes

- `OPENCLAW_PROFILE`
- `NATS_URL`
- `NATS_STREAM`
- `POSTGRES_URL`
- `WORKER_AGENT_ID`
- `WORKER_EXEC_MODE`
- `OPENCLAW_BIN`
- `OPENCLAW_HOME`
- `OPENCLAW_ENV_FILE`
- `OPENCLAW_UID`
- `OPENCLAW_GID`

## Nota

Este paquete se instala y reconcilia desde Ansible (`role: openclaw_control_plane`) y forma parte de la ClawOps Protocol Suite.
