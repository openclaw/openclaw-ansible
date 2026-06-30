---
title: Troubleshooting
description: Common OpenClaw Ansible installer failures and checks
---

# Troubleshooting

Start with the platform-specific checks below. Replace `openclaw` with your configured app user if you changed `openclaw_user`.

## Firewall blocks access

Only SSH and optional Tailscale are exposed publicly by default. Use an SSH tunnel for the local gateway port:

```bash
ssh -L 3000:localhost:3000 user@gateway-host
```

Debian/Ubuntu firewall checks:

```bash
sudo ufw status verbose
sudo iptables -L DOCKER-USER -n -v
```

Fedora/RHEL-family firewall checks:

```bash
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

Expected: SSH is allowed. Tailscale UDP `41641` is allowed only when `tailscale_enabled=true`.

## RedHat-family Quadlet does not start

Run these as the `openclaw` user:

```bash
loginctl show-user openclaw
systemctl --user daemon-reload
systemctl --user status openclaw.service
journalctl --user -u openclaw.service -n 100
podman info --format '{{.Host.Security.Rootless}}'
```

Expected:

- `Linger=yes`
- `podman info` prints `true`
- the Quadlet exists at `/home/openclaw/.config/containers/systemd/openclaw.container`

If rootless Podman cannot start, fix the rootless setup. Do not switch to rootful Podman; the installer intentionally has no rootful fallback.

## RedHat-family unsupported version failure

The installer rejects CentOS 7 and RHEL-family 7/8 because rootless Quadlets require newer Podman support. Use Fedora 38+ or a RHEL-family 9+ host.

## SELinux blocks Podman bind mounts

Do not disable SELinux. The generated Quadlet uses `:Z` labels for private OpenClaw state. Check AVC denials with your normal SELinux tooling, then verify the bind-mounted paths are owned by the `openclaw` user:

```bash
sudo ls -ld /home/openclaw/.openclaw /home/openclaw/.openclaw/workspace
```

## Debian/Ubuntu Docker sandbox issues

```bash
sudo systemctl status docker
sudo docker images | grep openclaw-sandbox
sudo iptables -L DOCKER-USER -n -v
```

Build the sandbox image from a source checkout when needed:

```bash
cd /opt/openclaw/openclaw
sudo -u openclaw ./scripts/sandbox-setup.sh
```

For npm installs without a source checkout, see the OpenClaw sandboxing documentation.

## Tailscale is installed but disconnected

```bash
sudo tailscale status
sudo tailscale up
```

For unattended setup, pass a Tailscale auth key through the documented Ansible variable and keep it out of logs and shell history.

## Node.js or pnpm missing

Check the installed versions:

```bash
node --version
pnpm --version
```

Re-run the playbook after fixing repository or package-manager errors:

```bash
./run-playbook.sh
```

## Ansible collection errors

Install required collections before running playbooks directly:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Verification

Run the security verification checklist after any fix:

```bash
ansible-playbook tests/verify-redhat-static.yml
```

For full host checks, follow `docs/security.md#verification`.
