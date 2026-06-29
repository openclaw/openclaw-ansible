---
title: Installation Guide
description: Detailed installation and configuration instructions
---

# Installation Guide

Use this guide to install OpenClaw on a supported Linux server with the OS-native firewall and container runtime.

## Supported platforms

| Platform | Version | Runtime |
| --- | --- | --- |
| Debian | 11+ | Docker CE + Compose V2 |
| Ubuntu | 20.04+ | Docker CE + Compose V2 |
| Fedora | 38+ | rootless Podman + rootless Quadlets |
| RHEL, CentOS Stream, AlmaLinux, Rocky Linux, Oracle Linux | 9+ | rootless Podman + rootless Quadlets |

CentOS 7 and RHEL-family 7/8 are unsupported.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ansible/main/install.sh | bash
```

## Manual installation

### Prerequisites

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y ansible git
```

Fedora/RHEL family:

```bash
sudo dnf install -y ansible git
```

### Clone and run

```bash
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbook.yml --ask-become-pass
```

## What the playbook installs

Debian/Ubuntu:

- UFW firewall
- fail2ban
- unattended-upgrades
- Docker CE + Compose V2
- Node.js + pnpm
- OpenClaw host CLI and state directories

Fedora/RHEL family:

- firewalld
- rootless Podman dependencies: `podman`, `slirp4netns`, `fuse-overlayfs`, `shadow-utils`
- SELinux support packages: `container-selinux`, `policycoreutils-python-utils`, `python3-libselinux`
- rootless user setup: `/etc/subuid`, `/etc/subgid`, and lingering
- rootless Quadlet at `/home/openclaw/.config/containers/systemd/openclaw.container`
- Node.js + pnpm
- OpenClaw host CLI and state directories

## Post-install setup

### Debian/Ubuntu

Switch to the OpenClaw user:

```bash
sudo su - openclaw
```

Run onboarding:

```bash
openclaw onboard --install-daemon
```

Then manage the daemon with the OpenClaw CLI:

```bash
openclaw status
openclaw logs
openclaw daemon restart
```

### Fedora/RHEL family

Switch to the OpenClaw user:

```bash
sudo su - openclaw
```

The playbook creates and starts the rootless Quadlet service. Check it with:

```bash
loginctl show-user openclaw
systemctl --user status openclaw.service
journalctl --user -u openclaw.service -f
```

Provider login and configuration still run as the `openclaw` user:

```bash
openclaw providers login
openclaw configure
```

## Firewall management

Debian/Ubuntu:

```bash
sudo ufw status verbose
sudo iptables -L DOCKER-USER -n -v
```

Fedora/RHEL family:

```bash
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

Only SSH and optional Tailscale should be exposed publicly by default.

## Rootless Podman operations

Run these as the `openclaw` user:

```bash
systemctl --user status openclaw.service
systemctl --user restart openclaw.service
journalctl --user -u openclaw.service -f
podman ps
podman logs -f openclaw
```

Quadlet location:

```text
/home/openclaw/.config/containers/systemd/openclaw.container
```

The installer never writes OpenClaw Quadlets to system Quadlet directories and never manages rootful Podman services.

## Accessing OpenClaw

OpenClaw binds to localhost by default. Use an SSH tunnel from your workstation:

```bash
ssh -L 3000:localhost:3000 user@gateway-host
```

Then browse to `http://localhost:3000`.

## Verification

Run the complete [post-install security verification](security.md#verification). It includes every command, the expected healthy result, and notes about host-specific output.

At minimum, confirm:

- The firewall is active.
- OpenClaw listens on `127.0.0.1`, not `0.0.0.0`.
- An external TCP scan exposes only SSH.
- Debian/Ubuntu: the `DOCKER-USER` chain drops externally routed container traffic.
- Fedora/RHEL family: Podman reports rootless mode as the `openclaw` user.
- Fedora/RHEL family: Quadlets are under `/home/openclaw/.config/containers/systemd/` only.
- Tailscale is connected when enabled.

## Uninstall

Debian/Ubuntu container/runtime cleanup:

```bash
sudo tailscale down
sudo rm -rf /opt/openclaw
sudo rm -rf /home/openclaw/.openclaw
sudo apt remove --purge tailscale docker-ce docker-ce-cli containerd.io docker-compose-plugin nodejs
sudo ufw disable
sudo ufw --force reset
```

Fedora/RHEL-family rootless Quadlet cleanup:

```bash
sudo su - openclaw
systemctl --user disable --now openclaw.service
rm -f ~/.config/containers/systemd/openclaw.container
systemctl --user daemon-reload
podman rm -f openclaw
exit
command -v tailscale >/dev/null 2>&1 && sudo tailscale down
sudo rm -rf /home/openclaw/.openclaw
```

Remove the user only after preserving any data you need:

```bash
sudo loginctl disable-linger openclaw
sudo loginctl terminate-user openclaw
sudo rm -f /etc/sudoers.d/openclaw
sudo userdel -r openclaw
```
