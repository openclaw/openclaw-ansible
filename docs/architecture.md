---
title: Architecture
description: OpenClaw Ansible installer task flow and platform-specific runtime architecture
---

# Architecture

The installer keeps one common OpenClaw setup flow and splits OS-native security/runtime tasks by OS family.

## Platform matrix

| Platform | Firewall | Container runtime | Service model |
| --- | --- | --- | --- |
| Debian/Ubuntu | UFW | Docker CE + Compose V2 | Host OpenClaw daemon installed during onboarding |
| Fedora/RHEL family | firewalld | rootless Podman only | Rootless Podman Quadlet under the `openclaw` user |

RedHat-family support requires Fedora 38+ or RHEL-family 9+. CentOS 7 and RHEL-family 7/8 are rejected because rootless Podman Quadlets are required.

## Task flow

```text
preflight.yml          # load OS vars, reject unsupported/rootful modes
system-tools.yml       # Debian apt tools or RedHat dnf tools
tailscale-*.yml        # optional Tailscale repo/package/service
user.yml               # create non-root openclaw user and user-systemd env
runtime setup          # Docker on Debian; rootless Podman user prep on RedHat
firewall setup         # UFW on Debian; firewalld on RedHat
nodejs.yml             # NodeSource packages for the OS family
openclaw.yml           # pnpm install and OpenClaw directories
quadlet-redhat.yml     # RedHat only: rootless Quadlet generation/start
```

## Debian and Ubuntu path

Debian-family hosts preserve the existing behavior:

1. Install Docker CE and Compose V2 from Docker's apt repository.
2. Add the `openclaw` user to the `docker` group.
3. Configure UFW default deny policies.
4. Add a DOCKER-USER chain to block externally forwarded Docker traffic.
5. Configure `/etc/docker/daemon.json` and restart Docker when it changes.
6. Install OpenClaw with pnpm; onboarding installs the host daemon.

Docker is installed for sandbox/container workflows. The gateway setup still runs through OpenClaw onboarding unless the operator chooses a different flow.

## Fedora and RHEL-family path

RedHat-family hosts use native packages and rootless Podman only:

1. Install Podman, rootless networking/storage helpers, firewalld, SELinux support, Node.js, and system tools with `dnf`.
2. Create the non-root `openclaw` user.
3. Ensure `/etc/subuid` and `/etc/subgid` ranges for the app user.
4. Enable linger with `loginctl enable-linger openclaw`.
5. Start the `user@<uid>.service` user manager.
6. Verify `podman info` reports rootless mode as the app user.
7. Configure firewalld permanent/immediate rules for SSH and optional Tailscale.
8. Generate `/home/openclaw/.config/containers/systemd/openclaw.container`.
9. Run `systemctl --user daemon-reload` and `systemctl --user enable --now openclaw.service` as the app user.

The RedHat path never starts rootful Podman services, never writes OpenClaw Quadlets to system Quadlet directories, and never falls back to Docker.

## Rootless Quadlet layout

```text
/home/openclaw/.config/containers/systemd/
└── openclaw.container

/home/openclaw/.openclaw/
├── .env
├── openclaw.json
└── workspace/
```

The Quadlet publishes localhost ports only:

```text
127.0.0.1:18789:18789
127.0.0.1:18790:18790
```

Bind mounts use SELinux private labels with `:Z`.

## Security boundaries

- Firewall rules expose SSH and optional Tailscale only.
- OpenClaw runs as an unprivileged `openclaw` user.
- Debian/Ubuntu uses UFW plus DOCKER-USER to prevent accidental Docker exposure.
- Fedora/RHEL-family uses rootless Podman and user-scoped systemd only.
- SELinux is not disabled.
- Rootful Podman is explicitly unsupported.

## Ansible collections

Required collections are declared in `requirements.yml`:

- `ansible.posix` for `firewalld` and authorized keys
- `community.general` for shared utility modules
- `community.docker` for Debian/Ubuntu Docker tasks
