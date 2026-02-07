---
title: Architecture
description: Technical implementation details
---

# Architecture

## Component Overview

```
┌─────────────────────────────────────────┐
│ UFW Firewall (SSH only)                 │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│ DOCKER-USER Chain (iptables)            │
│ Blocks all external container access    │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│ Docker Daemon                            │
│ - Non-root containers                    │
│ - Localhost-only binding                 │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│ Clawdbot Container                       │
│ User: clawdbot                           │
│ Port: 127.0.0.1:3000                     │
└──────────────────────────────────────────┘
```

## File Structure

```
/opt/clawdbot/
├── Dockerfile
├── docker-compose.yml

/home/clawdbot/.clawdbot/
├── config.yml
├── sessions/
└── credentials/

/etc/systemd/system/
└── clawdbot.service

/etc/docker/
└── daemon.json

/etc/ufw/
└── after.rules (DOCKER-USER chain)
```

## Service Management

Clawdbot runs as a systemd service that manages the Docker container:

```bash
# Systemd controls Docker Compose
systemd → docker compose → clawdbot container
```

## Installation Flow

1. **System Tools Setup** (`system-tools.yml` → `system-tools-linux.yml`)
   - Install essential packages (git, vim, curl, etc.)
   - Configure .bashrc for clawdbot user

2. **Tailscale Setup** (`tailscale-linux.yml`) - **OPTIONAL (disabled by default)**
   - Enabled via `tailscale_enabled: true`
   - Add Tailscale repository
   - Install Tailscale package
   - Display connection instructions

3. **User Creation** (`user.yml`)
   - Create `clawdbot` system user
   - Configure sudo permissions
   - Set up SSH keys

4. **Docker Installation** (`docker-linux.yml`)
   - Install Docker CE + Compose V2
   - Add user to docker group
   - Create `/etc/docker` directory

5. **Firewall Setup** (`firewall-linux.yml`)
   - Install UFW
   - Configure DOCKER-USER chain
   - Configure Docker daemon (`/etc/docker/daemon.json`)
   - Allow SSH (22/tcp) and conditionally Tailscale (41641/udp) if enabled
   - Install and configure fail2ban

6. **Node.js Installation** (`nodejs.yml`)
   - Add NodeSource repository
   - Install Node.js 22.x
   - Install pnpm globally

7. **Clawdbot Setup** (`clawdbot.yml`)
   - Create directories
   - Install via pnpm (release mode) or build from source (development mode)
   - Configure systemd service

## Key Design Decisions

### Why UFW + DOCKER-USER?

Docker manipulates iptables directly, bypassing UFW. The DOCKER-USER chain is evaluated before Docker's FORWARD chain, allowing us to block traffic before Docker sees it.

### Why Localhost Binding?

Defense in depth. Even if DOCKER-USER fails, localhost binding prevents external access.

### Why Systemd Service?

- Auto-start on boot
- Clean lifecycle management
- Integration with system logs
- Dependency management (after Docker)

### Why Non-Root Container?

Principle of least privilege. If container is compromised, attacker has limited privileges.

## Ansible Task Order

```
main.yml
├── system-tools.yml → system-tools-linux.yml (essential packages)
├── tailscale-linux.yml (VPN setup - optional, skipped if tailscale_enabled: false)
├── user.yml (create clawdbot user)
├── docker-linux.yml (install Docker, create /etc/docker)
├── firewall-linux.yml (configure UFW + Docker daemon + fail2ban)
├── nodejs.yml (Node.js + pnpm)
└── clawdbot.yml (release or development installation)
```

Order matters: Docker must be installed before firewall configuration because:
1. `/etc/docker` directory must exist for `daemon.json`
2. Docker service must exist to be restarted after config changes
