---
title: ClawOps Suite Architecture
summary: Arquitectura técnica de la suite operativa sobre OpenClaw (roles, flujos, capas y controles).
---

# ClawOps Suite Architecture

## Objetivo Arquitectónico

Separar claramente tres capas:

1. Capa producto (OpenClaw runtime).
2. Capa plataforma (Ansible roles/playbooks).
3. Capa operación (Makefile + `ops/*.sh` + smoke/runbooks).

Esta separación permite operación reproducible y control de drift en entornos reales.

## Mapa de Componentes

```mermaid
flowchart TB
  subgraph OPS[Operation Layer]
    MK[Makefile]
    SH[ops/*.sh]
    SM[smoke + backup/purge/install]
  end

  subgraph IA[Infrastructure as Code Layer]
    PB[playbooks/enterprise.yml]
    R1[role openclaw]
    R2[role openclaw_enterprise]
    R3[role openclaw_control_plane]
    R4[role openclaw_cloudflare_tunnel]
  end

  subgraph RT[Runtime Layer]
    GW[Gateway profiles]
    CP[Stage 2 Control Plane]
    CF[Cloudflare tunnel opcional]
  end

  MK --> SH --> PB
  PB --> R1
  PB --> R2
  PB --> R3
  PB --> R4

  R2 --> GW
  R3 --> CP
  R4 --> CF
```

## Stage 2 Runtime (Full/Lite)

```mermaid
flowchart LR
  IN[ingress] --> N[(NATS JetStream)]
  RT[router] --> N
  W[worker-*] --> N
  B[broker] --> N
  B --> P[(Postgres)]
  A[control-api] --> P

  O[observability full mode]:::obs
  O --> PR[prometheus]
  O --> GR[grafana]
  O --> UK[uptime-kuma]

  classDef obs fill:#eef,stroke:#99c,stroke-width:1px;
```

## Falencias Cubiertas por Diseño

| Falencia operativa | Respuesta en la suite |
|---|---|
| Instalación no repetible | Playbooks + defaults + inventarios por ambiente |
| Drift entre perfiles/agentes | Perfiles declarativos + reconciliación Ansible |
| Sin control de cola/estado | NATS + broker + control-api + PostgreSQL |
| Confirmaciones sin transición persistida | `control-api` actualiza estado y eventos en DB |
| Credenciales manuales por agente | `auth-sync` no interactivo por perfil/agente |
| Day-2 artesanal | Targets `make` estandarizados |

## Seguridad Operativa

- Secrets por perfil en `/etc/openclaw/secrets/*.env`.
- Servicios con aislamiento de usuario/perfil.
- Endpoints internos en loopback (publicación externa opcional por tunnel).
- Workers con UID/GID parametrizados para evitar supuestos rígidos de host.

## Rutas Críticas

- Playbook enterprise: `playbooks/enterprise.yml`
- Roles: `roles/openclaw*`
- Control-plane source: `control-plane/`
- Inventarios: `inventories/*`
- Operación: `ops/*`, `Makefile`

## Decisión de Compatibilidad

macOS bare-metal se considera fuera del modelo de ejecución seguro/soportado para esta suite.

## Relación con OpenClaw

Esta suite es una capa de protocolo y operación sobre OpenClaw; no reemplaza el producto.
