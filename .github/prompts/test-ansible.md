# Prompt: Simulated Ansible Run (Multi-OS) + Issue Vetting

You are an agent validating this Ansible playbook without running it on a real host. Simulate a run on one randomly selected host OS from: **Ubuntu Server**, **Linux Mint Desktop**, **Debian**, or **macOS**. Your job is to trace tasks, surface likely failures, and confirm that recently fixed issues remain resolved.

## Goals

1. Simulate playbook flow for the chosen OS.
2. Identify likely failures or logic errors.
3. Validate that OS-specific paths and repositories are correct.
4. Record any new issues or regressions.

## Choose an OS (random)

Pick one of:
- Ubuntu 22.04 Server
- Linux Mint 21 (Ubuntu-based)
- Debian 12
- macOS 13

Document the choice at the top of your report.

## Static Simulation Checklist

### 1) Playbook Entry and Pre-Tasks

- Confirm OS detection variables are set correctly:
  - `is_macos`, `is_linux`, `is_debian`, `is_linux_mint`, `ubuntu_codename`.
- Verify pre-tasks do not reference unsupported package managers.
- Confirm Homebrew prerequisites are installed on Linux **before** the Homebrew install task.

**Expected safe behavior**:
- Linux: apt update/upgrade runs, Homebrew prerequisites installed, Homebrew install gated by existence.
- macOS: no apt tasks run; Homebrew install uses `/opt/homebrew/bin/brew`.

### 2) Role Task Flow (roles/openclaw/tasks/main.yml)

Confirm order:
1. system-tools
2. tailscale
3. user
4. docker
5. firewall
6. nodejs
7. openclaw

**Note:** Docker is intentionally before firewall because firewall writes `/etc/docker/daemon.json`.

### 3) OS-Specific Routing

Ensure these files are used by OS:
- Linux: `system-tools-linux.yml`, `tailscale-linux.yml`, `docker-linux.yml`, `firewall-linux.yml`, `nodejs-linux.yml`
- macOS: `system-tools-macos.yml`, `tailscale-macos.yml`, `docker-macos.yml`, `firewall-macos.yml`, `nodejs-macos.yml`

### 4) Known Prior Issues (Verify Resolved)

Check for the following fixes in the codebase:

- **Node.js tasks on macOS**
  - Should not use apt. Must use Homebrew tasks in `roles/openclaw/tasks/nodejs-macos.yml`.

- **Debian Docker/Tailscale repos**
  - Docker repository should use `linux/debian` and Debian codename.
  - Tailscale repo should use `debian` and Debian codename.

- **macOS home path**
  - `openclaw_home` must resolve to `/Users/openclaw` on macOS.
  - Tasks must not hardcode `/home/openclaw`.

- **Welcome message location**
  - Should use `{{ openclaw_home }}`.
  - On macOS, `.zshrc` should source the welcome message.

- **pnpm configuration**
  - `pnpm` config must run with a PATH that includes Homebrew and user bin directories.

### 5) Walk Through the Chosen OS

Trace tasks for your chosen OS and note anything suspicious:

- **system-tools**
  - Linux: apt packages installed, `.bashrc`/`.zshrc` config added.
  - macOS: Homebrew installs tools, `.zshrc` configured.

- **tailscale**
  - Linux: Repo setup uses correct distro string.
  - macOS: Cask install and status checks.

- **user**
  - User created with correct shell and home path.
  - Linux only: DBus/XDG runtime setup tasks.

- **docker**
  - Linux: repo uses correct distro/codename.
  - macOS: Docker Desktop install and socket wait.

- **firewall**
  - Linux: UFW + DOCKER-USER chain in `/etc/ufw/after.rules`.
  - macOS: Application Firewall check and enable.

- **nodejs**
  - Linux: NodeSource repo and `nodejs` install.
  - macOS: Homebrew `node` + `pnpm` install.

- **openclaw**
  - Directories created.
  - `pnpm config` runs with the right PATH.
  - Release/dev install path validation.

### 6) Post-Tasks

- Welcome message created under `{{ openclaw_home }}`.
- `.bashrc` always gets the welcome source line.
- `.zshrc` gets the welcome source line on macOS.

## Report Template

Copy this and fill it out:

```
Chosen OS: <Ubuntu 22.04 | Linux Mint 21 | Debian 12 | macOS 13>

Summary:
- Simulated playbook flow: <ok | issues found>
- Regression checks: <pass | fail>

Findings:
1) <issue or confirmation>
2) <issue or confirmation>

If Issues Found:
- Suspected file(s): <path>
- Suspected task(s): <task name>
- Why it would fail: <reason>
- Proposed fix: <summary>

Regression Checklist:
- [ ] Node.js macOS tasks use Homebrew
- [ ] Debian uses correct Docker repository
- [ ] Debian uses correct Tailscale repository
- [ ] macOS home path is /Users/openclaw
- [ ] Welcome message uses {{ openclaw_home }}
- [ ] pnpm config has PATH that includes Homebrew
```

## Extra Verification (Optional)

If you can run local checks, run these in the repository:
- `ansible-playbook playbook.yml --syntax-check`
- `ansible-playbook playbook.yml --check`

Capture any errors and include them in your report.
