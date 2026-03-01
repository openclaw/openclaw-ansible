---
title: Troubleshooting
description: Common issues and solutions
---

# Troubleshooting

## Container Can't Reach Internet

**Symptom**: OpenClaw can't connect to WhatsApp/Telegram

**Check**:
```bash
# Test from container
sudo docker exec openclaw ping -c 3 8.8.8.8

# Check UFW allows outbound
sudo ufw status verbose | grep OUT
```

**Solution**:
```bash
# Verify DOCKER-USER allows established connections
sudo iptables -L DOCKER-USER -n -v

# Restart Docker + Firewall
sudo systemctl restart docker
sudo ufw reload
sudo systemctl restart openclaw
```

## Port Already in Use

**Symptom**: Port 3000 conflict

**Solution**:
```bash
# Find what's using port 3000
sudo ss -tlnp | grep 3000

# Change OpenClaw port
sudo nano /opt/openclaw/docker-compose.yml
# Change: "127.0.0.1:3001:3000"

sudo systemctl restart openclaw
```

## Firewall Lockout

**Symptom**: Can't SSH after installation

**Solution** (via console/rescue mode):
```bash
# Disable UFW temporarily
sudo ufw disable

# Check SSH rule exists
sudo ufw status numbered

# Re-add SSH rule
sudo ufw allow 22/tcp

# Re-enable
sudo ufw enable
```

## Container Won't Start

**Check logs**:
```bash
# Systemd logs
sudo journalctl -u openclaw -n 50

# Docker logs
sudo docker logs openclaw

# Compose status
sudo docker compose -f /opt/openclaw/docker-compose.yml ps
```

**Common fixes**:
```bash
# Rebuild image
cd /opt/openclaw
sudo docker compose build --no-cache
sudo systemctl restart openclaw

# Check permissions
sudo chown -R openclaw:openclaw /home/openclaw/.openclaw
```

## Verify Docker Isolation

**Test that external ports are blocked**:
```bash
# Start test container
sudo docker run -d -p 80:80 --name test-nginx nginx

# From EXTERNAL machine (should fail):
curl http://YOUR_SERVER_IP:80

# From SERVER (should work):
curl http://localhost:80

# Cleanup
sudo docker rm -f test-nginx
```

## UFW Status Shows Inactive

**Fix**:
```bash
# Enable UFW
sudo ufw enable

# Reload rules
sudo ufw reload

# Verify
sudo ufw status verbose
```

## Ansible Playbook Fails

**Collection missing**:
```bash
ansible-galaxy collection install -r requirements.yml
```

**Permission denied**:
```bash
# Run with --ask-become-pass
ansible-playbook playbook.yml --ask-become-pass
```

**Docker daemon not running**:
```bash
sudo systemctl start docker
# Re-run playbook
```

## Gateway Unreachable After Tailscale Exposure Change (dev-main)

**Symptom**:
- `openclaw --profile dev-main status --all` shows gateway unreachable (`ECONNREFUSED 127.0.0.1:18789`)
- `gateway probe` may show `Connect: ok` but `RPC: failed - timeout`
- Mixed state after switching to `gateway.bind=tailnet` or enabling internal `gateway.tailscale.mode=serve`

**Root cause**:
- Local profile clients still target loopback (`ws://127.0.0.1:18789`) while gateway binding/exposure was changed.
- Residual `tailscale ssh`/forward processes can remain attached to the service cgroup.
- Internal Tailscale serve from non-interactive service users may fail depending on tailnet policy.

**Remediation (safe baseline)**:
```bash
# 1) Keep gateway local-only
sudo -iu openclaw /home/openclaw/.local/bin/openclaw --profile dev-main config set gateway.bind loopback
sudo -iu openclaw /home/openclaw/.local/bin/openclaw --profile dev-main config set gateway.tailscale.mode off

# 2) Restart user service using openclaw user DBus
uid=$(id -u openclaw)
export XDG_RUNTIME_DIR=/run/user/$uid
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
sudo -u openclaw XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS \
  systemctl --user restart openclaw-gateway-dev-main.service
sudo -u openclaw XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS \
  systemctl --user enable openclaw-gateway-dev-main.service

# 3) Validate
sudo -iu openclaw /home/openclaw/.local/bin/openclaw --profile dev-main gateway probe
sudo -iu openclaw /home/openclaw/.local/bin/openclaw --profile dev-main status --all
```

**Expected healthy probe**:
- `Local loopback ws://127.0.0.1:18789`
- `Connect: ok`
- `RPC: ok`

**Expose dashboard over Tailscale (recommended pattern)**:
- Keep OpenClaw bind on loopback.
- Expose separately with Tailscale Serve (HTTPS path), only if Serve is enabled in tailnet admin:
```bash
sudo tailscale serve --bg http://127.0.0.1:18789
tailscale serve status
```

**Security follow-up**:
- If a token appeared in process command lines (`OPENCLAW_GATEWAY_TOKEN=...`), rotate it immediately:
```bash
sudo -iu openclaw /home/openclaw/.local/bin/openclaw --profile dev-main doctor --generate-gateway-token
uid=$(id -u openclaw)
export XDG_RUNTIME_DIR=/run/user/$uid
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
sudo -u openclaw XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS \
  systemctl --user restart openclaw-gateway-dev-main.service
```
