---
title: Enterprise Deployment (ClawOps Suite)
summary: Despliegue multi-ambiente y multi-perfil con OpenClaw + Stage 2 bajo un protocolo operativo único.
---

# Enterprise Deployment

## Propósito

Estandarizar despliegues enterprise donde un solo host o conjunto de hosts necesita:

- múltiples perfiles gateway,
- múltiples agentes por perfil,
- control de colas/estado,
- operación repetible y auditable.

## Qué se despliega

- `playbooks/enterprise.yml`
- `roles/openclaw`
- `roles/openclaw_enterprise`
- `roles/openclaw_control_plane`
- `roles/openclaw_cloudflare_tunnel` (opcional)

## Modelo Multi-Perfil

Cada perfil define al menos:

- estado (`state_dir`, `config_path`, `workspace_root`),
- puerto gateway,
- secretos de entorno,
- lista de agentes,
- políticas de tools/modelos/sandbox.

## Modelo Stage 2

Dos modos soportados:

- `full`: cola completa + observabilidad.
- `lite`: camino mínimo para ejecución directa.

## Ejecución

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/enterprise.yml --become
```

o

```bash
./run-enterprise-playbook.sh dev
```

## Comportamiento de Rollout

- `serial` configurable.
- tolerancia configurable a hosts no disponibles.
- ejecución progresiva para reducir riesgo de corte total.

## Secrets y Gobernanza

Variables sensibles deben residir en vault por ambiente:

- tokens gateway,
- credenciales NATS/Postgres,
- tokens Telegram,
- credenciales tunnel si aplica.

La suite escribe archivos de entorno por perfil y separa secretos de configuración funcional.

## Qué Falencia Cubre Este Modo Enterprise

1. Evita mezcla de estados entre perfiles.
2. Permite aislar rutas de agentes por contexto de negocio.
3. Habilita crecimiento incremental sin re-arquitectura manual.
4. Reduce dependencia de pasos ad-hoc en operadores individuales.

## Integración con Operación Day-2

Para operación continua usar:

- `make install`
- `make auth-sync`
- `make smoke`
- `make backup`
- `make purge CONFIRM=1`

## Referencias

- [Operations Workflow](operations-workflow.md)
- [Stage 2 Control Plane](control-plane-stage2.md)
- [Operator Runbook](operator-runbook.md)
