# OpenClaw Ansible Installer

![OpenClaw Ansible banner](docs/assets/readme-banner.jpg)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lint](https://github.com/openclaw/openclaw-ansible/actions/workflows/lint.yml/badge.svg)](https://github.com/openclaw/openclaw-ansible/actions/workflows/lint.yml)
[![Ansible](https://img.shields.io/badge/Ansible-2.14+-blue.svg)](https://www.ansible.com/)
[![Multi-OS](https://img.shields.io/badge/OS-Debian%20%7C%20Ubuntu%20%7C%20Fedora%20%7C%20RHEL--family-orange.svg)](https://www.ansible.com/)

Automated, hardened installation of [OpenClaw](https://github.com/openclaw/openclaw) with OS-native firewall and container runtime support.

## Supported platforms

| Platform | Version | Firewall | Container runtime |
| --- | --- | --- | --- |
| Debian | 11+ | UFW | Docker CE + Compose V2 |
| Ubuntu | 20.04+ | UFW | Docker CE + Compose V2 |
| Fedora | 38+ | firewalld | rootless Podman + rootless Quadlets |
| RHEL, CentOS Stream, AlmaLinux, Rocky Linux, Oracle Linux | 9+ | firewalld | rootless Podman + rootless Quadlets |

CentOS 7 and RHEL-family 7/8 are unsupported because this installer requires rootless Podman Quadlets on RedHat-family systems.

## RedHat-family security model

Fedora, RHEL, CentOS Stream, AlmaLinux, Rocky Linux, and Oracle Linux installs use the native RedHat-family stack:

- `dnf`/`yum` packages, not Debian package names
- `firewalld`, not UFW
- `podman`, not Docker
- rootless Podman only
- rootless Quadlets only, written to `/home/<app-user>/.config/containers/systemd/`
- SELinux-compatible bind mounts with private `:Z` labels

Rootful Podman is intentionally unsupported. The playbook fails instead of starting rootful Podman services, using system Quadlet directories, or falling back to Docker on RedHat-family systems.

## macOS support is disabled

Bare-metal macOS installs are disabled. Use a Linux VM or server instead.

## Features

- 🔒 **Firewall-first**: UFW on Debian/Ubuntu; firewalld on Fedora/RHEL-family systems
- 🛡️ **Fail2ban**: SSH brute-force protection on Debian/Ubuntu
- 🔄 **Auto-updates**: Automatic security patches via unattended-upgrades on Debian/Ubuntu
- 🔐 **Tailscale VPN**: Secure remote access without exposing services
- 🐳 **Container runtime**: Docker on Debian/Ubuntu; rootless Podman Quadlets on Fedora/RHEL-family systems
- 🚀 **One-command install**: Complete setup in minutes
- 🔧 **Auto-configuration**: DBus, systemd, environment setup
- 📦 **pnpm installation**: Uses `pnpm install -g openclaw@latest`

## Quick Start (Standalone / Self-Hosted)

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
./run-playbook.sh -e openclaw_install_mode=development
```

## What Gets Installed

- Tailscale (mesh VPN, optional)
- Firewall rules for SSH and optional Tailscale access
- Docker CE + Compose V2 on Debian/Ubuntu
- rootless Podman + rootless Quadlets on Fedora/RHEL-family systems
- Node.js 22.x + pnpm
- OpenClaw host CLI and state directories
- Systemd environment setup for the `openclaw` user

## Post-Install

After installation completes, switch to the openclaw user:

```bash
sudo su - openclaw
```

On Debian/Ubuntu, run the quick-start onboarding wizard:

```bash
openclaw onboard --install-daemon
```

On Fedora/RHEL-family systems, the playbook installs a rootless Quadlet service. Manage it as the `openclaw` user:

```bash
systemctl --user status openclaw.service
journalctl --user -u openclaw.service -f
```

After onboarding, run the [post-install security verification](docs/security.md#verification). The checks confirm that the firewall and SSH protection are active, published container ports remain localhost-only or externally blocked, and OpenClaw does not listen publicly.

### Alternative Manual Setup

```bash
# Configure manually
openclaw configure

# Login to provider
openclaw providers login

# Test gateway
openclaw gateway

# Install as daemon on Debian/Ubuntu if not using onboard
openclaw daemon install
openclaw daemon start

# Check status
openclaw status
openclaw logs
```

## Manual Installation

### Release Mode (Default)

Debian/Ubuntu:

```bash
sudo apt update && sudo apt install -y ansible git
```

Fedora/RHEL-family:

```bash
sudo dnf install -y ansible git
```

Then run:

```bash
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible
ansible-galaxy collection install -r requirements.yml
./run-playbook.sh
```

### Development Mode

Build from source for development:

```bash
./run-playbook.sh -e openclaw_install_mode=development
```

This will:
- Clone openclaw repo to `~/code/openclaw`
- Run `pnpm install` and `pnpm build`
- Symlink binary to `~/.local/bin/openclaw`
- Add development aliases to `.bashrc`

## Installation as Ansible Collection

`openclaw.installer` is an Ansible collection and can be installed with the `ansible-galaxy` command:

```bash
ansible-galaxy collection install git+https://github.com/openclaw/openclaw-ansible.git
```

Alternatively, add it to the [`requirements.yml` file of your Ansible project](https://docs.ansible.com/ansible/latest/collections_guide/collections_installing.html#install-multiple-collections-with-a-requirements-file) as follows:

```yaml
collections:
  - name: https://github.com/openclaw/openclaw-ansible.git
    type: git
    version: main
```

As a version, you can use a branch, a version tag (e.g., `v2.0.0`), or a specific commit hash.

### Usage

First copy the sample inventory to `inventory.yml`.

```bash
cp inventory-sample.yml inventory.yml
```

Second edit the inventory file to match your cluster setup. For example:

```yaml
openclaw_servers:
  children:
    server:
      hosts:
        192.16.35.11:
        192.16.35.12:
```

If needed, you can also edit `vars` section to match your environment.

Start provisioning of the server using one of the following commands. The command to be used depends on whether you installed `openclaw.installer` with `ansible-galaxy` or if you run the playbook from within the cloned git repository:

*Installed with ansible-galaxy*

```bash
ansible-playbook openclaw.installer.deploy -i inventory.yml
```

*In your existing playbook*

```yaml
- name: Deploy OpenClaw
  hosts: my_servers
  become: true
  roles:
    - openclaw.installer.openclaw
```

*Running the playbook from inside the repository*

```bash
ansible-playbook playbooks/deploy.yml -i inventory.yml
```

Alternatively, to run the playbook from your existing project setup, run the playbook from within your own playbook:

*Installed with ansible-galaxy*

```yaml
- name: Deploy OpenClaw
  ansible.builtin.import_playbook: openclaw.installer.deploy
```

*Running the playbook from inside the repository*

```yaml
- name: Deploy OpenClaw
  ansible.builtin.import_playbook: playbooks/deploy.yml
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

## RedHat-family operations

Run these as the `openclaw` user unless noted:

```bash
loginctl show-user openclaw
systemctl --user status openclaw.service
journalctl --user -u openclaw.service -f
podman ps
```

Quadlet files live in:

```text
/home/openclaw/.config/containers/systemd/openclaw.container
```

The playbook configures `/etc/subuid`, `/etc/subgid`, and `loginctl enable-linger openclaw` so the rootless user service can persist after reboot.

## Security

- **Public ports**: SSH (22), Tailscale (41641/udp) only
- **Fail2ban**: SSH brute-force protection on Debian/Ubuntu
- **Automatic updates**: Security patches via unattended-upgrades on Debian/Ubuntu
- **Docker isolation**: Debian/Ubuntu Docker publishes are blocked externally through DOCKER-USER
- **Rootless Podman**: Fedora/RHEL-family installs never use rootful Podman
- **Non-root**: OpenClaw runs as unprivileged user
- **Scoped sudo**: Limited to service management (not full root)
- **Systemd hardening**: NoNewPrivileges, PrivateTmp, ProtectSystem where OpenClaw installs a host daemon
- **SELinux**: RedHat-family installs keep SELinux enabled and use `:Z` labels for container bind mounts

Run the [post-install security verification](docs/security.md#verification) for commands and expected results. In the default configuration, an external TCP scan should show only SSH on port 22; Tailscale uses UDP and is not included in that TCP scan.

### Security Note

For high-security environments, audit before running:

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ansible/main/install.sh -o install.sh
less install.sh
bash install.sh
```

## Configuration

See [docs/configuration.md](docs/configuration.md) for all available variables and customization options.

## Documentation

- [Installation Guide](docs/installation.md)
- [Security Architecture](docs/security.md)
- [Configuration Reference](docs/configuration.md)
- [Troubleshooting](docs/troubleshooting.md)

## Support

- OpenClaw issues: https://github.com/openclaw/openclaw/issues
- Installer issues: https://github.com/openclaw/openclaw-ansible/issues
