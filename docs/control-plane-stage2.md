---
title: Stage 2 Control Plane (ClawOps Suite)
summary: Capa de orquestación de cola/estado para operación multi-agente en OpenClaw enterprise.
---

# Stage 2 Control Plane

## Contexto

Stage 2 es la respuesta a una necesidad operativa: cuando hay múltiples agentes y perfiles, hace falta un plano de control explícito para enrutar, persistir, observar y decidir.

## Modos

- `full`:
  - NATS + Postgres
  - ingress/router/broker/control-api
  - workers múltiples
  - observabilidad (Prometheus/Grafana/Uptime Kuma)
- `lite`:
  - NATS + Postgres
  - ingress/router-forced-main/worker-main/broker/control-api

## Flujo Operativo

1. `ingress` publica tarea.
2. `router` decide destino.
3. `worker` ejecuta.
4. `broker` persiste y publica salida.
5. `control-api` consulta estados y aplica decisiones.

## Endpoints Principales

- Ingress: `http://127.0.0.1:<ingress_port>/telegram/webhook`
- Simulación: `http://127.0.0.1:<ingress_port>/ingress/simulate`
- Control API: `http://127.0.0.1:<control_api_port>/tasks`
- Cola: `http://127.0.0.1:<control_api_port>/queues`

## Endurecimientos Incluidos

- Health probe con defaults coherentes por modo (`full`/`lite`).
- UID/GID de worker parametrizado (`OPENCLAW_UID/OPENCLAW_GID`).
- Confirm/reject con transición real de estado en DB.
- Reconciliación SQL de password con escaping seguro.

## Integración con la Suite

Se habilita vía `openclaw_control_plane_enabled` y perfiles en inventario.

Despliegue recomendado:

```bash
make install
make smoke
```

## Referencias

- [Operator Runbook](operator-runbook.md)
- [Operations Workflow](operations-workflow.md)
- [Architecture](architecture.md)
