---
title: Security Architecture
description: Firewall configuration and Docker isolation details
---

# Security Architecture

## Overview

This playbook implements a 4-layer defense strategy to ensure only SSH (port 22) is accessible from the internet.

## Layer 1: UFW Firewall

```bash
# Default policies
Incoming: DENY
Outgoing: ALLOW
Routed: DENY

# Allowed
SSH (22/tcp): ALLOW
Tailscale (41641/udp): ALLOW
```

## Layer 2: DOCKER-USER Chain

Custom iptables chain that prevents Docker from bypassing UFW:

```
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -i lo -j ACCEPT
-A DOCKER-USER -i <default_interface> -j DROP
COMMIT
```

**Result**: Even `docker run -p 80:80 nginx` won't expose port 80 externally.

## Layer 3: Localhost-Only Binding

All container ports bind to 127.0.0.1:

```yaml
ports:
  - "127.0.0.1:3000:3000"
```

## Layer 4: Non-Root Container

Container processes run as unprivileged `openclaw` user.

## Verification

```bash
# Check firewall
sudo ufw status verbose

# Check Tailscale status
sudo tailscale status

# Check Docker isolation
sudo iptables -L DOCKER-USER -n -v

# Port scan from external machine (only SSH + Tailscale should be open)
nmap -p- YOUR_SERVER_IP

# Test container isolation
sudo docker run -d -p 80:80 nginx
curl http://YOUR_SERVER_IP:80  # Should fail/timeout
curl http://localhost:80        # Should work
```

## Tailscale Access

OpenClaw's web interface (port 3000) is bound to localhost. Access it via:

1. **SSH tunnel**:
   ```bash
   ssh -L 3000:localhost:3000 user@server
   # Then browse to http://localhost:3000
   ```

2. **Tailscale** (recommended):
   ```bash
   # On server: already done by playbook
   sudo tailscale up
   
   # From your machine:
   # Browse to http://TAILSCALE_IP:3000
   ```

## Network Flow

```
Internet → UFW (SSH only) → DOCKER-USER Chain → DROP (unless localhost/established)
Container → NAT → Internet (outbound allowed)
```
