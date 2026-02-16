# OpenClaw Ansible Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lint](https://github.com/openclaw/openclaw-ansible/actions/workflows/lint.yml/badge.svg)](https://github.com/openclaw/openclaw-ansible/actions/workflows/lint.yml)
[![Ansible](https://img.shields.io/badge/Ansible-2.14+-blue.svg)](https://www.ansible.com/)
[![Multi-OS](https://img.shields.io/badge/OS-Debian%20%7C%20Ubuntu-orange.svg)](https://www.debian.org/)

Automated, hardened installation of [OpenClaw](https://github.com/openclaw/openclaw) with Docker and Tailscale VPN support for Debian/Ubuntu Linux.

## ⚠️ macOS Support: Deprecated & Disabled

**Effective 2026-02-06, support for bare-metal macOS installations has been removed from this playbook.**

### Why?
The underlying project currently requires system-level permissions and configurations that introduce significant security risks when executed on a primary host OS. To protect user data and system integrity, we have disabled bare-metal execution.

### What does this mean?
* The playbook will now explicitly fail if run on a `Darwin` (macOS) system.
* We strongly discourage manual workarounds to bypass this check.
* **Future Support:** We are evaluating a virtualization-first strategy (using Vagrant or Docker) to provide a sandboxed environment for this project in the future.

## Features

- 🔒 **Firewall-first**: UFW firewall + Docker isolation
- 🛡️ **Fail2ban**: SSH brute-force protection out of the box
- 🔄 **Auto-updates**: Automatic security patches via unattended-upgrades
- 🔐 **Tailscale VPN**: Secure remote access without exposing services
- 🐳 **Docker**: Docker CE with security hardening
- 🚀 **One-command install**: Complete setup in minutes
- 🔧 **Auto-configuration**: DBus, systemd, environment setup
- 📦 **pnpm installation**: Uses `pnpm install -g openclaw@latest`

## Quick Start

### Release Mode (Recommended)

Install the latest stable version from npm:

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ansible/main/install.sh | bash
```

### Development Mode

Install from source for development or testing:

```bash
# Clone the installer
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible

# Install in development mode
ansible-playbook playbook.yml --ask-become-pass -e openclaw_install_mode=development
```

## What Gets Installed

- Tailscale (mesh VPN)
- UFW firewall (SSH + Tailscale ports only)
- Docker CE + Compose V2 (for sandboxes)
- Node.js 22.x + pnpm
- OpenClaw on host (not containerized)
- Systemd service (auto-start)

## Post-Install

After installation completes, switch to the openclaw user:

```bash
sudo su - openclaw
```

Then run the quick-start onboarding wizard:

```bash
openclaw onboard --install-daemon
```

This will:
- Guide you through the setup wizard
- Configure your messaging provider (WhatsApp/Telegram/Signal)
- Install and start the daemon service

### Alternative Manual Setup

```bash
# Configure manually
openclaw configure

# Login to provider
openclaw providers login

# Test gateway
openclaw gateway

# Install as daemon
openclaw daemon install
openclaw daemon start

# Check status
openclaw status
openclaw logs
```

## Installation Modes

### Release Mode (Default)
- Installs via `pnpm install -g openclaw@latest`
- Gets latest stable version from npm registry
- Automatic updates via `pnpm install -g openclaw@latest`
- **Recommended for production**

### Development Mode
- Clones from `https://github.com/openclaw/openclaw.git`
- Builds from source with `pnpm build`
- Symlinks binary to `~/.local/bin/openclaw`
- Adds helpful aliases:
  - `openclaw-rebuild` - Rebuild after code changes
  - `openclaw-dev` - Navigate to repo directory
  - `openclaw-pull` - Pull, install deps, and rebuild
- **Recommended for development and testing**

Enable with: `-e openclaw_install_mode=development`

## Security

- **Public ports**: SSH (22), Tailscale (41641/udp) only
- **Fail2ban**: SSH brute-force protection (5 attempts → 1 hour ban)
- **Automatic updates**: Security patches via unattended-upgrades
- **Docker isolation**: Containers can't expose ports externally (DOCKER-USER chain)
- **Non-root**: OpenClaw runs as unprivileged user
- **Scoped sudo**: Limited to service management (not full root)
- **Systemd hardening**: NoNewPrivileges, PrivateTmp, ProtectSystem

Verify: `nmap -p- YOUR_SERVER_IP` should show only port 22 open.

### Security Note

For high-security environments, audit before running:

```bash
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible
# Review playbook.yml and roles/
ansible-playbook playbook.yml --check --diff  # Dry run
ansible-playbook playbook.yml --ask-become-pass
```


## Security Hardening

This playbook includes comprehensive security hardening that is enabled by default:

### SSH Hardening

- **Disabled password authentication** - Key-based auth only
- **Disabled root login** - Must use regular user with sudo
- **Strong ciphers only** - AES-256-GCM, ChaCha20-Poly1305
- **Strong key exchange** - Curve25519, DH Group Exchange SHA256
- **Session timeouts** - Idle sessions disconnected after 10 minutes
- **Rate limiting** - MaxStartups 10:30:60, MaxAuthTries 3
- **Security banner** - Warns unauthorized users

### Kernel Hardening

Network security via sysctl:
- **SYN flood protection** - TCP syncookies enabled
- **IP spoofing prevention** - Reverse path filtering
- **ICMP hardening** - Redirects disabled, broadcasts ignored
- **Source routing disabled** - Prevents source route attacks

Kernel security:
- **ASLR enabled** - Full address space randomization
- **Kernel pointer restriction** - kptr_restrict=2
- **dmesg restriction** - Non-root can't read kernel logs
- **Ptrace restriction** - Yama ptrace_scope=1
- **Symlink/hardlink protection** - Prevents privilege escalation

### Audit Logging

Comprehensive security event logging via auditd:
- **Authentication events** - Login attempts, PAM changes, passwd/shadow modifications
- **Privilege escalation** - sudo/su usage, setuid/setgid calls
- **Network changes** - Firewall rules, hosts file, network config
- **SSH config changes** - sshd_config modifications
- **OpenClaw specific** - Config changes, service modifications, binary execution
- **Docker monitoring** - Daemon config, container operations
- **Kernel modules** - Module loading/unloading events
- **Time changes** - System clock modifications

### Configuration Options

All security features can be toggled via variables:

```yaml
# In your playbook or via -e flag
ssh_hardening_enabled: true      # SSH hardening (default: true)
kernel_hardening_enabled: true   # Kernel sysctl hardening (default: true)
audit_logging_enabled: true      # Auditd logging (default: true)

# Additional options
disable_usb_storage: false       # Disable USB storage devices
harden_tmp_mount: false          # Mount /tmp with noexec,nosuid,nodev
```

**⚠️ Warning**: Before enabling SSH hardening, ensure you have SSH key access configured. Password authentication will be disabled!

### Viewing Audit Logs

```bash
# View recent security events
sudo ausearch -ts recent

# View failed login attempts
sudo ausearch -m USER_LOGIN -sv no

# View sudo usage
sudo ausearch -k sudo_usage

# View OpenClaw config changes
sudo ausearch -k openclaw_config

# Generate audit report
sudo aureport --summary
```

### Compliance

These hardening measures align with:
- CIS Benchmark for Debian/Ubuntu
- NIST 800-53 security controls
- SOC 2 Type II requirements

## Documentation

- [Configuration Guide](docs/configuration.md) - All configuration options
- [Development Mode](docs/development-mode.md) - Build from source
- [Security Architecture](docs/security.md) - Security details
- [Technical Details](docs/architecture.md) - Architecture overview
- [Troubleshooting](docs/troubleshooting.md) - Common issues
- [Agent Guidelines](AGENTS.md) - AI agent instructions

## Requirements

- Debian 11+ or Ubuntu 20.04+
- Root/sudo access
- Internet connection

## What Gets Installed

- Tailscale (mesh VPN)
- UFW firewall (SSH + Tailscale ports only)
- Docker CE + Compose V2 (for sandboxes)
- Node.js 22.x + pnpm
- OpenClaw on host (not containerized)
- Systemd service (auto-start)

## Manual Installation

### Release Mode (Default)

```bash
# Install dependencies
sudo apt update && sudo apt install -y ansible git

# Clone repository
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Run installation
./run-playbook.sh
```

### Development Mode

Build from source for development:

```bash
# Same as above, but with development mode flag
./run-playbook.sh -e openclaw_install_mode=development

# Or directly:
ansible-playbook playbook.yml --ask-become-pass -e openclaw_install_mode=development
```

This will:
- Clone openclaw repo to `~/code/openclaw`
- Run `pnpm install` and `pnpm build`
- Symlink binary to `~/.local/bin/openclaw`
- Add development aliases to `.bashrc`

## Configuration Options

All configuration variables can be found in [`roles/openclaw/defaults/main.yml`](roles/openclaw/defaults/main.yml).

You can override them in three ways:

### 1. Via Command Line

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e openclaw_install_mode=development \
  -e "openclaw_ssh_keys=['ssh-ed25519 AAAAC3... user@host']"
```

### 2. Via Variables File

```bash
# Create vars.yml
cat > vars.yml << EOF
openclaw_install_mode: development
openclaw_ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx user@host"
  - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... user@host"
openclaw_repo_url: "https://github.com/YOUR_USERNAME/openclaw.git"
openclaw_repo_branch: "feature-branch"
tailscale_authkey: "tskey-auth-xxxxxxxxxxxxx"
EOF

# Use it
ansible-playbook playbook.yml --ask-become-pass -e @vars.yml
```

### 3. Edit Defaults Directly

Edit `roles/openclaw/defaults/main.yml` before running the playbook.

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `openclaw_user` | `openclaw` | System user name |
| `openclaw_home` | `/home/openclaw` | User home directory |
| `openclaw_install_mode` | `release` | `release` or `development` |
| `openclaw_ssh_keys` | `[]` | List of SSH public keys |
| `openclaw_repo_url` | `https://github.com/openclaw/openclaw.git` | Git repository (dev mode) |
| `openclaw_repo_branch` | `main` | Git branch (dev mode) |
| `tailscale_authkey` | `""` | Tailscale auth key for auto-connect |
| `nodejs_version` | `22.x` | Node.js version to install |

See [`roles/openclaw/defaults/main.yml`](roles/openclaw/defaults/main.yml) for the complete list.

### Common Configuration Examples

#### SSH Keys for Remote Access

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e "openclaw_ssh_keys=['ssh-ed25519 AAAAC3... user@host']"
```

#### Development Mode with Custom Repository

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e openclaw_install_mode=development \
  -e openclaw_repo_url=https://github.com/YOUR_USERNAME/openclaw.git \
  -e openclaw_repo_branch=feature-branch
```

#### Tailscale Auto-Connect

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e tailscale_authkey=tskey-auth-xxxxxxxxxxxxx
```

## License

MIT - see [LICENSE](LICENSE)

## Support

- OpenClaw: https://github.com/openclaw/openclaw
- This installer: https://github.com/openclaw/openclaw-ansible/issues
