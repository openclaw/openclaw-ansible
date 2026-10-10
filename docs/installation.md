---
title: Installation Guide
description: Detailed installation and configuration instructions
---

# Installation Guide

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ansible/main/install.sh | bash
```

Both `install.sh` and `run-playbook.sh` support running as root. System setup
runs as root, while OpenClaw package installation and source builds run as the
dedicated OpenClaw user. Do not pass `-e ansible_become=false`: that overrides
the role's task-level user switching and runs those commands as root too.

Reapplying development mode also repairs ownership of an existing checkout
created by an older root invocation before Git and build tasks switch users.
This preserves local file contents and permissions and does not follow symlinks
to files outside the checkout.

## Manual Installation

### Prerequisites

Ansible-core 2.14 or newer is required (`meta/runtime.yml`). On Debian 12+ and
Ubuntu 24.04+, the distro package is new enough:

```bash
sudo apt update
sudo apt install -y ansible git
ansible-playbook --version   # first line must show [core 2.14] or newer
```

On Ubuntu 22.04 and Debian 11, the distro Ansible package is too old. Install
Ansible in a virtual environment using the distro's Python (3.9 or newer), then
select both Ansible commands from that environment:

```bash
sudo apt update
sudo apt install -y python3-venv git
python3 -m venv "$HOME/.local/share/openclaw-ansible"
"$HOME/.local/share/openclaw-ansible/bin/python" -m pip install 'ansible-core>=2.14'
export PATH="$HOME/.local/share/openclaw-ansible/bin:$PATH"
ansible-playbook --version
ansible-galaxy --version
```

Run `install.sh` from this shell without prefixing it with `sudo`; it requests
sudo only for system operations. Both version banners must report core 2.14 or
newer. Pip selects a release compatible with the environment's Python.

Ubuntu 20.04's default Python 3.8 cannot run ansible-core 2.14. For the local
bootstrap, upgrade to Ubuntu 24.04 first. Alternatively, provision the older
target from a separate supported Ansible controller using the
[remote inventory workflow](../README.md#installation-as-ansible-collection).
Installing with the default `pip3` on Ubuntu 20.04 does not satisfy the requirement.

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

### 1. Connect to Tailscale

```bash
# Interactive login
sudo tailscale up

# Or with auth key for automation
sudo tailscale up --authkey tskey-auth-xxxxx

# Check status
sudo tailscale status
```

Get auth keys from: https://login.tailscale.com/admin/settings/keys

### 2. Configure OpenClaw and Install the Gateway Service

Switch to the dedicated account and run onboarding:

```bash
sudo su - openclaw
openclaw onboard --install-daemon
```

Onboarding creates `~/.openclaw/openclaw.json` (JSON5), guides provider setup, and installs the native Gateway as a systemd user service. The Ansible role prepares directories and dependencies but does not create the application configuration or service. There is no installer-managed `config.yml` or OpenClaw container.

## Service Management

Run these as the OpenClaw user:

```bash
openclaw gateway status
openclaw gateway stop
openclaw gateway start
openclaw gateway restart
openclaw logs
```

For systemd inspection, the default user unit is `openclaw-gateway.service`:

```bash
systemctl --user status openclaw-gateway.service
journalctl --user -u openclaw-gateway.service -n 50
```

The installer does not add systemd sandboxing directives to this unit. See [service security](security.md#native-gateway-service) and the [upstream Gateway runbook](https://docs.openclaw.ai/gateway) for configuration and service details.

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

The native Gateway defaults to loopback port `18789`. Use the actual port reported by `openclaw gateway status` if you changed it during configuration.

### Via SSH Tunnel

```bash
ssh -N -L 18789:127.0.0.1:18789 user@server
# Then browse to: http://localhost:18789
```

The server can be reached through its Tailscale address. Connecting Tailscale alone does not make a loopback listener reachable at the server's Tailscale IP. For direct browser access, configure [Tailscale Serve](https://docs.openclaw.ai/gateway/tailscale) separately.

## Verification

Run the complete [post-install security verification](security.md#verification). It includes every command, the expected healthy result, and notes about output that varies by host.

At minimum, confirm:

- UFW is active with incoming and routed traffic denied by default.
- The `sshd` fail2ban jail is enabled.
- OpenClaw listens on `127.0.0.1`, not `0.0.0.0`.
- The `DOCKER-USER` chain drops externally routed container traffic.
- An external TCP scan exposes only the configured SSH port.
- A published test container works locally but cannot be reached externally.
- Tailscale is connected when enabled, and unattended upgrades are active.

## Uninstall

First back up any configuration and data you need. As the OpenClaw user, remove the onboarding-managed service:

```bash
openclaw gateway stop
openclaw gateway uninstall
```

Then, as an administrator, remove the account or packages only if they are no longer needed. Removing the account's home deletes its OpenClaw data; Docker, Node.js, Tailscale, and firewall rules may be shared with other services.

## Advanced Configuration

Use `openclaw configure` as the OpenClaw user for application settings. Gateway ports, credentials, and channel policy belong to `~/.openclaw/openclaw.json`, not a Compose file. See the [upstream configuration guide](https://docs.openclaw.ai/gateway/configuration) for supported settings and restart requirements.

The legacy installer variable `openclaw_port` does not configure the native Gateway. Use onboarding or OpenClaw configuration to change the port.

## Automation

### Unattended Install

```bash
# Set Tailscale auth key in playbook vars
ansible-playbook playbook.yml \
  --ask-become-pass \
  -e "tailscale_authkey=tskey-auth-xxxxx"
```

### CI/CD Integration

```yaml
# Example GitHub Actions
- name: Deploy OpenClaw
  run: |
    ansible-playbook playbook.yml \
      -e "tailscale_authkey=${{ secrets.TAILSCALE_KEY }}" \
      --become
```
