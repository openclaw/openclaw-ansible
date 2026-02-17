# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible playbook for automated, security-hardened installation of **Clawdbot** (AI messaging bot) on Debian/Ubuntu Linux and macOS. Single-role architecture targeting localhost only (`connection: local`).

## Commands

```bash
# Lint (CI runs all three)
yamllint .
ansible-lint playbook.yml
ansible-playbook playbook.yml --syntax-check

# Dry run (no changes made)
ansible-playbook playbook.yml --check --diff

# Full install
./run-playbook.sh

# Install with variables
ansible-playbook playbook.yml --ask-become-pass -e clawdbot_install_mode=development
```

## Architecture

**Execution flow**: `install.sh` → `run-playbook.sh` → `playbook.yml` → `roles/clawdbot/`

`playbook.yml` has three phases:
1. **Pre-tasks**: OS detection (sets `is_macos`, `is_debian`, `is_linux` facts), apt upgrade, Homebrew setup, Galaxy collection install
2. **Role `clawdbot`**: All installation work via `tasks/main.yml`
3. **Post-tasks**: Welcome message, systemd service symlink

### Critical: Task Ordering in `roles/clawdbot/tasks/main.yml`

The include order is load-bearing and must not be rearranged:

```
system-tools → tailscale → user → docker → firewall → nodejs → clawdbot
```

**Docker must come before firewall** because `firewall.yml` writes `/etc/docker/daemon.json` (needs `/etc/docker/` to exist) and restarts the Docker service.

### OS-Conditional Task Pattern

Many tasks use an orchestrator file that dispatches to OS-specific files:
- `docker.yml` → `docker-linux.yml` / `docker-macos.yml`
- `firewall.yml` → `firewall-linux.yml` / `firewall-macos.yml`
- `tailscale.yml` → `tailscale-linux.yml` / `tailscale-macos.yml`
- `system-tools.yml` → `system-tools-linux.yml` / `system-tools-macos.yml`

### Security Architecture (Defense in Depth)

UFW + DOCKER-USER iptables chain + localhost port binding + non-root container + scoped sudo + fail2ban + unattended-upgrades + systemd hardening.

Docker bypasses UFW by default; the DOCKER-USER chain in `/etc/ufw/after.rules` blocks external traffic before Docker sees it. The chain uses dynamic interface detection (never hardcode `eth0`).

## Key Constraints

- **Never** set `iptables: false` in Docker daemon config (breaks container networking)
- **Always** use `127.0.0.1:HOST_PORT:CONTAINER_PORT` for port binding, never `0.0.0.0`
- **No `become_user`** in tasks (playbook runs as root already)
- Use `community.docker.docker_compose_v2` (not deprecated `docker_compose`)
- Use `docker compose` V2 syntax (not `docker-compose` V1)
- Use loops instead of repeated tasks
- Variables for all paths/ports in templates
- Add new collections to `requirements.yml`
- Verify idempotency (tasks must be safe to run multiple times)

## Key Files

- `roles/clawdbot/defaults/main.yml` — All configurable variables (install mode, ports, user, paths)
- `roles/clawdbot/handlers/main.yml` — Service restart handlers (docker, fail2ban)
- `roles/clawdbot/templates/` — Jinja2 templates (daemon.json, systemd service, clawdbot config, vimrc)
- `requirements.yml` — Galaxy collections: `community.docker >=3.4.0`, `community.general >=8.0.0`
- `.ansible-lint` — Production profile; skips `var-naming`, `risky-shell-pipe`, `command-instead-of-module`
- `.yamllint` — 120-char line length, 2-space indent
- `AGENTS.md` — Extended contributor/agent guidelines with security rationale
