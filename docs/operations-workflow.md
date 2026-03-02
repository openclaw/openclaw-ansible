---
title: Operations Workflow (ClawOps Suite)
summary: Protocolo day-2 para operar OpenClaw enterprise de manera repetible.
---

# Operations Workflow

## Idea Central

La suite define un protocolo simple: cada operación crítica debe tener un comando único y repetible.

Por eso `Makefile` expone comandos estables y `ops/*.sh` encapsula la implementación.

## Ciclo Canónico

```bash
make backup
make purge CONFIRM=1
make install
make auth-sync PROFILES="dev-main andrea" OAUTH_PROVIDER=openai-codex
make smoke
```

Para ejecución completa:

```bash
make reinstall CONFIRM=1
```

## Comandos y Rol Operativo

- `make backup`: preserva estado operativo antes de cambios.
- `make purge`: limpia estado runtime para reinstalación controlada.
- `make install`: reconcilia enterprise + control-plane.
- `make auth-sync`: propaga credenciales Codex a perfiles/agentes.
- `make smoke`: valida salud + flujo cola end-to-end.

## Auth-Sync como Control de Deriva

`auth-sync` existe para resolver una falencia operativa común: credenciales divergentes por agente/perfil.

Estrategia:

1. Fuente central en `/home/efra/.codex`.
2. Espejo en `/home/openclaw/.codex`.
3. Escritura determinista de `auth-profiles.json` por agente.
4. Alineación de modelo por perfil.

## Validación de Secretos

`make install` ejecuta validación previa de secretos para bloquear despliegues incompletos.

Complemento:

```bash
make secrets-refactor
```

Genera base de migración manual para homogeneizar vault por ambiente.

## Qué Falencias Cubre Este Workflow

1. Cambios manuales no auditables.
2. Reinstalaciones inconsistentes.
3. Pérdida de estado por no hacer backup previo.
4. Despliegues "verdes" sin smoke real de cola.

## Defaults de Operación

- `ENV=dev`
- `INVENTORY=inventories/dev/hosts.yml`
- `LIMIT=zennook`
- `PROFILES="dev-main andrea"`

## Referencias

- [Operator Runbook](operator-runbook.md)
- [Enterprise Deployment](enterprise-deployment.md)
- [Installed Runtime Layout](architecture-installed-layout.md)
