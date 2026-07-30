---
title: Security Architecture
description: Firewall, container isolation, and security hardening details
---

# Security Architecture

This playbook uses OS-native security controls. Debian and Ubuntu keep the existing Docker + UFW model. Fedora and RHEL-family systems use firewalld and rootless Podman Quadlets only.

## Security layers by platform

| Layer | Debian/Ubuntu | Fedora/RHEL family |
| --- | --- | --- |
| Firewall | UFW | firewalld |
| SSH protection | fail2ban | firewalld baseline; add fail2ban separately if desired |
| Security updates | unattended-upgrades | OS vendor update tooling |
| Container runtime | Docker CE + Compose V2 | rootless Podman only |
| Service model | OpenClaw user service/daemon | rootless Podman Quadlet under the app user |
| SELinux | Usually not enforcing by default | Kept enabled; bind mounts use `:Z` |

## Debian and Ubuntu

### UFW firewall

```bash
# Default policies
Incoming: DENY
Outgoing: ALLOW
Routed: DENY

# Allowed
SSH (22/tcp): ALLOW
Tailscale (41641/udp): ALLOW when tailscale_enabled=true
```

### Fail2ban SSH protection

```bash
sudo fail2ban-client status sshd
```

The default jail allows 5 failed attempts in 10 minutes and bans for 1 hour.

### DOCKER-USER chain

The playbook adds a DOCKER-USER chain that drops externally forwarded traffic before Docker can expose it:

```text
-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -i lo -j ACCEPT
-A DOCKER-USER -i <default_interface> -j DROP
```

Result: even `docker run -p 80:80 nginx` should not expose port 80 externally.

### Automatic security updates

Unattended-upgrades installs security updates automatically. Automatic reboots are disabled.

## Fedora and RHEL-family systems

### firewalld

The playbook installs, enables, and starts `firewalld`. It opens:

- `22/tcp` for SSH
- `41641/udp` for Tailscale when `tailscale_enabled=true`

Rules are permanent and immediate through `ansible.posix.firewalld`.

### Rootless Podman only

RedHat-family installs use rootless Podman and rootless Quadlets. The playbook intentionally does not support rootful Podman.

The playbook fails instead of:

- enabling rootful Podman services
- writing Quadlets to system directories
- falling back to Docker
- using a root app user

Rootless setup includes:

- `/etc/subuid` and `/etc/subgid` ranges for the `openclaw` user
- `loginctl enable-linger openclaw`
- app-user-owned Quadlet directory at `/home/openclaw/.config/containers/systemd/`
- user-scoped `systemctl --user daemon-reload`
- user-scoped `systemctl --user enable --now openclaw.service`

### SELinux

SELinux stays enabled. The rootless Quadlet uses private labels on bind mounts:

```text
Volume=/home/openclaw/.openclaw:/home/node/.openclaw:Z
Volume=/home/openclaw/.openclaw/workspace:/home/node/.openclaw/workspace:Z
```

Use `:Z` for private OpenClaw container state. Do not disable SELinux to work around mount issues.

## Verification

Run these checks after installation and onboarding. Interface names, IP addresses, counters, and process IDs vary by host; compare the stated healthy result rather than expecting byte-for-byte output.

### Firewall

Debian/Ubuntu:

```bash
sudo ufw status verbose
```

Expected: `Status: active`, with incoming and routed traffic denied by default. The default rules allow `22/tcp` for SSH and, when Tailscale is enabled, `41641/udp`.

Fedora/RHEL family:

```bash
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

Expected: firewalld is running. The active zone allows SSH and, when Tailscale is enabled, `41641/udp`.

### Local listeners

```bash
sudo ss -tlnp
```

Expected: SSH listens on the configured public address or `0.0.0.0`; OpenClaw and supporting services listen on `127.0.0.1`. No OpenClaw service should listen on `0.0.0.0`.

### Debian/Ubuntu Docker isolation

```bash
sudo iptables -L DOCKER-USER -n -v
```

Expected: the chain accepts established and loopback traffic, then drops traffic arriving on the server's default external interface.

From another machine, scan the server:

```bash
nmap -p- YOUR_SERVER_IP
```

Expected: only the configured SSH TCP port is open in the default configuration.

Then publish a temporary container port:

```bash
sudo docker run -d -p 80:80 --name test-nginx nginx
curl --connect-timeout 5 http://YOUR_SERVER_IP:80
curl --fail http://localhost:80
sudo docker rm -f test-nginx
```

Expected: the external request fails or times out, while the localhost request returns the nginx welcome page.

### Fedora/RHEL rootless Podman

Run these as the `openclaw` user:

```bash
loginctl show-user openclaw
systemctl --user status openclaw.service
journalctl --user -u openclaw.service -n 100
podman info --format '{{.Host.Security.Rootless}}'
podman ps
```

Expected:

- `Linger=yes` for `openclaw`
- `openclaw.service` exists under the user systemd manager
- Podman reports `true` for rootless mode
- Quadlet file exists at `/home/openclaw/.config/containers/systemd/openclaw.container`

Also confirm no rootful Quadlet path is used:

```bash
test ! -e /etc/containers/systemd/openclaw.container
```

### Tailscale

```bash
sudo tailscale status
```

When Tailscale is enabled, expected: the server has a `100.x.x.x` Tailscale address and appears in the peer table. `Logged out` or `Stopped` means `sudo tailscale up` still needs to be completed. Skip this check when `tailscale_enabled` is false.

## Tailscale access

OpenClaw binds to localhost by default. Access it with an SSH tunnel unless you intentionally configure another private access path:

```bash
ssh -L 3000:localhost:3000 user@gateway-host
```

Then browse to `http://localhost:3000` from your workstation.

## Known limitations

### Unsupported RedHat-family versions

CentOS 7 and RHEL-family 7/8 are unsupported because the installer requires rootless Podman Quadlets. Use Fedora 38+ or a RHEL-family 9+ host.

### Rootful Podman

Rootful Podman is not supported and will not be added as a fallback. If rootless Podman cannot start, fix the rootless user, subuid/subgid, lingering, or systemd user manager state.

### IPv6

Docker IPv6 is disabled by default on Debian/Ubuntu (`ip6tables: false` in `daemon.json`). If your network uses IPv6, review and test firewall rules accordingly.

### Installation script

The `curl | bash` installation pattern has inherent risks. For high-security environments, clone the repository and audit before running. Consider `ansible-playbook playbook.yml --check` first.

## Security checklist

After installation, verify:

- [ ] Only SSH and optional Tailscale are exposed publicly
- [ ] Debian/Ubuntu: `sudo ufw status` is active
- [ ] Debian/Ubuntu: `sudo fail2ban-client status sshd` shows the jail active
- [ ] Debian/Ubuntu: `sudo iptables -L DOCKER-USER -n` shows the drop rule
- [ ] Fedora/RHEL family: `sudo firewall-cmd --state` reports `running`
- [ ] Fedora/RHEL family: `podman info` as `openclaw` reports rootless mode
- [ ] Fedora/RHEL family: Quadlet file is under `/home/openclaw/.config/containers/systemd/`
- [ ] Fedora/RHEL family: no OpenClaw Quadlet exists under a system Quadlet directory
- [ ] External TCP scan shows only the configured SSH port
- [ ] Tailscale access works when enabled

## Reporting security issues

If you discover a security vulnerability, please report it privately:

- OpenClaw: https://github.com/openclaw/openclaw/security
- This installer: https://github.com/openclaw/openclaw-ansible/security
