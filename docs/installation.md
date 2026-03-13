---
title: Installation Guide
description: Detailed installation and configuration instructions
---

# Installation Guide

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ansible/main/install.sh | bash
```

## Manual Installation

### Prerequisites

```bash
sudo apt update
sudo apt install -y ansible git
```

### Clone and Run

```bash
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Run playbook
ansible-playbook playbook.yml --ask-become-pass
```

## Post-Installation

### 1. Connect VPN (if not auto-connected)

If you set `vpn_provider` but didn't provide an auth/setup key, connect manually:

**Tailscale:**
```bash
sudo tailscale up
sudo tailscale status
```
Get auth keys from: https://login.tailscale.com/admin/settings/keys

**Netbird:**
```bash
sudo netbird up
sudo netbird status
```
Get setup keys from: https://app.netbird.io/setup-keys

### 2. Configure OpenClaw

```bash
# Edit config
sudo nano /home/openclaw/.openclaw/config.yml

# Key settings to configure:
# - provider: whatsapp/telegram/signal
# - phone: your number
# - ai.provider: anthropic/openai
# - ai.model: claude-3-5-sonnet-20241022
```

### 3. Login to Provider

```bash
# Login (will prompt for QR code or phone verification)
sudo docker exec -it openclaw openclaw login

# Check connection
sudo docker logs -f openclaw
```

## Service Management

### Systemd Commands

```bash
# Start/stop/restart
sudo systemctl start openclaw
sudo systemctl stop openclaw
sudo systemctl restart openclaw

# View status
sudo systemctl status openclaw

# Enable/disable auto-start
sudo systemctl enable openclaw
sudo systemctl disable openclaw
```

### Docker Commands

```bash
# View logs
sudo docker logs openclaw
sudo docker logs -f openclaw  # follow

# Shell access
sudo docker exec -it openclaw bash

# Restart container
sudo docker restart openclaw

# Check status
sudo docker compose -f /opt/openclaw/docker-compose.yml ps
```

### Firewall Management

```bash
# View UFW status
sudo ufw status verbose

# Add custom rule
sudo ufw allow 8080/tcp comment 'Custom service'
sudo ufw reload

# View Docker isolation
sudo iptables -L DOCKER-USER -n -v
```

## Accessing OpenClaw

OpenClaw's web interface runs on port 3000 (localhost only).

### Via VPN (Recommended)

```bash
# After connecting your VPN (Tailscale or Netbird), browse to:
http://VPN_IP:3000
```

Wait, port 3000 is bound to localhost, so this won't work directly. Need to update the compose file or use SSH tunnel.

### Via SSH Tunnel

```bash
ssh -L 3000:localhost:3000 user@server
# Then browse to: http://localhost:3000
```

## Verification

### Security Check

```bash
# Check open ports (should show only SSH + VPN)
sudo ss -tlnp

# External port scan (only port 22 should be open)
nmap -p- YOUR_SERVER_IP

# Test container isolation
sudo docker run -d -p 80:80 --name test-nginx nginx
curl http://YOUR_SERVER_IP:80  # Should fail
curl http://localhost:80        # Should work
sudo docker rm -f test-nginx
```

### UFW Status

```bash
sudo ufw status verbose

# Expected output:
# Status: active
# To                         Action      From
# --                         ------      ----
# 22/tcp                     ALLOW IN    Anywhere
# 41641/udp                  ALLOW IN    Anywhere
```

### VPN Status

**Tailscale:**
```bash
sudo tailscale status
```

**Netbird:**
```bash
sudo netbird status
```

## Uninstall

```bash
# Stop services
sudo systemctl stop openclaw
sudo systemctl disable openclaw
# sudo tailscale down  (if using Tailscale)
# sudo netbird down    (if using Netbird)

# Remove containers and data
sudo docker compose -f /opt/openclaw/docker-compose.yml down
sudo rm -rf /opt/openclaw
sudo rm -rf /home/openclaw/.openclaw
sudo rm /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload

# Remove packages (optional)
sudo apt remove --purge tailscale netbird docker-ce docker-ce-cli containerd.io docker-compose-plugin nodejs

# Remove user (optional)
sudo userdel -r openclaw

# Reset firewall (optional)
sudo ufw disable
sudo ufw --force reset
```

## Advanced Configuration

### Custom Port

Edit `/opt/openclaw/docker-compose.yml`:

```yaml
ports:
  - "127.0.0.1:3001:3000"  # Change 3001 to desired port
```

Then restart:
```bash
sudo systemctl restart openclaw
```

### Environment Variables

Add to `/opt/openclaw/docker-compose.yml`:

```yaml
environment:
  - NODE_ENV=production
  - ANTHROPIC_API_KEY=sk-ant-xxx
  - DEBUG=openclaw:*
```

### Volume Mounts

Add additional volumes in docker-compose.yml:

```yaml
volumes:
  - /home/openclaw/.openclaw:/home/openclaw/.openclaw
  - /path/to/custom:/custom
```

## Automation

### Unattended Install

```bash
# Netbird example
ansible-playbook playbook.yml \
  --ask-become-pass \
  -e vpn_provider=netbird \
  -e "netbird_setup_key=your-setup-key"

# Tailscale example
ansible-playbook playbook.yml \
  --ask-become-pass \
  -e vpn_provider=tailscale \
  -e "tailscale_authkey=tskey-auth-xxxxx"
```

### CI/CD Integration

```yaml
# Example GitHub Actions (Netbird)
- name: Deploy OpenClaw
  run: |
    ansible-playbook playbook.yml \
      -e vpn_provider=netbird \
      -e "netbird_setup_key=${{ secrets.NETBIRD_SETUP_KEY }}" \
      --become
```
