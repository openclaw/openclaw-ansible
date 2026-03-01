---
title: Operations Workflow (Backup, Purge, Install)
summary: Makefile-driven clean install/uninstall cycle for OpenClaw + Stage 2 control-plane
---

# Operations Workflow

This repository provides a Makefile interface over `ops/*.sh` scripts:

- `make backup`
- `make purge CONFIRM=1`
- `make install`
- `make oauth-login`
- `make smoke`
- `make reinstall CONFIRM=1`

## Why this split

- `Makefile`: stable operator commands.
- `ops/*.sh`: implementation details, safe to extend.

## OAuth note (Codex)

`openai-codex` login is interactive by design (browser OAuth callback).
It cannot be made fully non-interactive without changing provider auth semantics.

Use:

```bash
make oauth-login PROFILES="dev-main andrea" OAUTH_PROVIDER=openai-codex
```

## Defaults

- `ENV=dev`
- `INVENTORY=inventories/dev/hosts.yml`
- `LIMIT=zennook`
- `PROFILES="dev-main andrea"`

Override per command, for example:

```bash
make install ENV=staging LIMIT=fedora
```
