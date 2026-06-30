# Agent Guidelines

## Project Overview

Ansible playbook for automated, hardened OpenClaw installation on Linux servers.

Supported platform families:

- Debian/Ubuntu: UFW + Docker CE + Compose V2.
- Fedora/RHEL family: firewalld + rootless Podman + rootless Quadlets only.

## Key Principles

1. **Security First**: configure firewall and runtime isolation before exposing services.
2. **One Command Install**: `curl | bash` should work on supported platforms.
3. **Localhost Only**: container-published ports bind to `127.0.0.1` unless explicitly documented otherwise.
4. **OS-Native Runtime**: Debian keeps Docker; RedHat-family uses rootless Podman only.
5. **No Rootful Podman**: never implement or suggest rootful Podman fallback.

## Critical Components

### Task Order

Task order in `roles/openclaw/tasks/main.yml`:

```yaml
- preflight.yml          # OS vars, support checks, rootless policy
- system-tools.yml       # OS-family package map
- tailscale-*.yml        # optional VPN setup
- user.yml               # app user and user-systemd env
- docker-linux.yml       # Debian/Ubuntu only
- podman-redhat.yml      # RedHat-family rootless setup only
- firewall-linux.yml     # Debian/Ubuntu UFW + DOCKER-USER
- firewall-redhat.yml    # RedHat-family firewalld
- nodejs.yml             # OS-family NodeSource setup
- openclaw.yml           # OpenClaw install/state dirs
- quadlet-redhat.yml     # RedHat-family rootless Quadlet only
```

### Debian/Ubuntu Runtime

- Docker must be installed before Debian firewall configuration because `firewall-linux.yml` writes `/etc/docker/daemon.json` and restarts Docker.
- DOCKER-USER rules live in `/etc/ufw/after.rules` and must use dynamic interface detection.
- Never use `iptables: false` in Docker daemon config.
- Keep Docker port bindings on `127.0.0.1`.

### Fedora/RHEL Runtime

- Use `dnf`/`yum`-compatible packages and RedHat package names.
- Use `firewalld`, not UFW.
- Use `podman`, not Docker.
- Rootless Podman only. Rootful Podman must fail fast.
- Rootless Quadlets only under `/home/{{ openclaw_user }}/.config/containers/systemd/`.
- Never write OpenClaw Quadlets under system Quadlet directories.
- Manage services with `systemctl --user` as `{{ openclaw_user }}` and set `XDG_RUNTIME_DIR=/run/user/{{ openclaw_uid_value }}`.
- Keep SELinux enabled. Use `:Z` labels for private OpenClaw bind mounts.

## Code Style

### Ansible

- Use loops instead of repeated tasks.
- Prefer modules over shell/command when modules are safe.
- Shell/command tasks need accurate `changed_when`.
- Keep OS-specific behavior isolated by vars/tasks.
- Always specify collections in `requirements.yml`.

### Docker

- Debian/Ubuntu only.
- Use `docker compose` V2, not deprecated `docker-compose` V1.
- No `version:` in compose files.

### Podman

- RedHat-family only in this installer.
- Use rootless Quadlet files.
- Do not enable rootful `podman.service` or `podman.socket`.
- Do not add a `docker` group on RedHat-family systems.

## Testing Checklist

Before committing changes:

```bash
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbooks/deploy.yml --syntax-check
ansible-playbook tests/verify.yml --syntax-check
ansible-playbook tests/verify-redhat-static.yml --syntax-check
ansible-playbook tests/verify-redhat-static.yml
ansible-lint playbook.yml
yamllint .
```

Platform validation on disposable hosts:

```bash
# Debian/Ubuntu
sudo ufw status verbose
sudo iptables -L DOCKER-USER -n
sudo ss -tlnp
sudo docker run -p 80:80 nginx

# Fedora/RHEL family
sudo firewall-cmd --state
sudo firewall-cmd --list-all
sudo su - openclaw
loginctl show-user openclaw
podman info --format '{{.Host.Security.Rootless}}'
systemctl --user status openclaw.service
journalctl --user -u openclaw.service -n 100
test ! -e /etc/containers/systemd/openclaw.container
```

## Common Mistakes to Avoid

1. ❌ Regressing Debian/Ubuntu Docker + UFW behavior.
2. ❌ Installing Docker or creating a `docker` group on RedHat-family systems.
3. ❌ Using rootful Podman or adding rootful fallback.
4. ❌ Writing Quadlets to system Quadlet directories.
5. ❌ Running RedHat-family Quadlet commands with system-level `systemctl`.
6. ❌ Disabling SELinux.
7. ❌ Hardcoding network interface names.
8. ❌ Using `0.0.0.0` port bindings.

## Documentation

- **README.md**: installation, quick start, supported matrix.
- **docs/**: architecture, security, troubleshooting.
- **AGENTS.md**: this file.

Keep docs concise. No progress logs or refactoring summaries.

## File Locations

### Host System

```text
/opt/openclaw/                                      # Installation files when source mode uses it
/home/openclaw/.openclaw/                          # Config and data
/etc/docker/daemon.json                            # Debian/Ubuntu only
/etc/ufw/after.rules                               # Debian/Ubuntu only
/home/openclaw/.config/containers/systemd/         # RedHat-family rootless Quadlets
```

### Repository

```text
roles/openclaw/
├── tasks/       # Ansible tasks
├── templates/   # Jinja2 configs and Quadlets
├── defaults/    # Shared defaults
├── vars/        # OS-family variables
└── handlers/    # Service restart handlers
```

## Security Notes

### Why UFW + DOCKER-USER on Debian/Ubuntu?

Docker bypasses UFW by default. DOCKER-USER is evaluated first, allowing the installer to block forwarded traffic before Docker sees it.

### Why firewalld + rootless Podman on RedHat-family systems?

firewalld, SELinux, and rootless Podman are the native RedHat-family stack. Rootless Quadlets keep container lifecycle under the app user's systemd manager instead of a rootful daemon.

### Why Fail2ban?

SSH is exposed to the internet. Fail2ban automatically bans IPs after repeated failed attempts on Debian/Ubuntu.

### Why Scoped Sudo?

The `openclaw` user only needs limited service and Tailscale commands. Full root access would be dangerous if the app is compromised.

## Making Changes

### Adding a New Task

1. Add to the appropriate OS-family task file.
2. Update `roles/openclaw/tasks/main.yml` only if a new task file is needed.
3. Add OS-family vars when package names or runtime behavior differ.
4. Test with `--syntax-check` first.
5. Verify idempotency on a disposable host.

### Changing Firewall Rules

1. Test on a disposable VM first.
2. Always keep SSH accessible.
3. Update `docs/security.md`.
4. Verify with an external port scan.

### Updating Runtime Config

- Debian/Ubuntu: changes to `daemon.json.j2` trigger Docker restart.
- RedHat-family: changes to `openclaw.container.j2` require user daemon reload and user service restart.

## Support Channels

- OpenClaw issues: https://github.com/openclaw/openclaw
- This installer: https://github.com/openclaw/openclaw-ansible
