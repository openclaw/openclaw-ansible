# Testing

This document describes the automated testing infrastructure for the Ansible playbook, including the Docker-based CI test harness that validates convergence, correctness, and idempotency.

## Overview

The test harness runs the entire playbook inside a Docker container to verify that:

1. **Convergence**: The playbook completes without errors
2. **Verification**: The system reaches the expected state
3. **Idempotency**: Running the playbook twice produces no changes on the second run

This approach provides fast, reliable CI testing without requiring actual VMs or complex infrastructure.

## Quick Start

```bash
# Run all tests
bash tests/run-tests.sh

# Or specify a distribution
bash tests/run-tests.sh ubuntu2404
```

**Expected output:**
```
Building test image (ubuntu2404)...
Running tests...
===> Step 1: Convergence test
===> Convergence: PASSED
===> Step 2: Verification
===> Verification: PASSED
===> Step 3: Idempotency test
===> Idempotency: PASSED (0 changed)
===> All tests passed
```

## Test Infrastructure

### Test Files

The test harness consists of several files in the `tests/` directory:

#### `Dockerfile.ubuntu2404`
Defines an Ubuntu 24.04 container with Ansible pre-installed:
- Installs Ansible and dependencies (python3, git, curl, sudo, etc.)
- Copies the entire project into `/opt/ansible`
- Installs Ansible Galaxy collections from `requirements.yml`
- Sets the entrypoint to run the test script

#### `entrypoint.sh`
The main test execution script that runs inside the container:
- **Step 1**: Runs the playbook with `ci_test=true` (convergence test)
- **Step 2**: Runs `verify.yml` to validate system state
- **Step 3**: Runs the playbook again and checks for zero changes (idempotency)

#### `verify.yml`
Post-convergence assertions that check:
- User creation (`clawdbot` user exists)
- Package installation (git, curl, vim, jq, tmux, tree, htop)
- Node.js and pnpm installation
- Directory structure (`.clawdbot/`, subdirectories, permissions)
- Configuration files (sudoers, vim config, git global config)

#### `run-tests.sh`
Local test runner script:
- Builds the Docker image
- Runs the container with the test entrypoint
- Returns the exit code (0 = success, 1 = failure)

## CI Test Mode

### The `ci_test` Variable

The playbook supports a special `ci_test` variable that modifies behavior for containerized testing:

```yaml
# Set in roles/clawdbot/defaults/main.yml
ci_test: false  # Default: run all tasks
```

When `ci_test=true`, the playbook skips tasks that cannot run in an unprivileged Docker container:

#### Skipped Tasks

| Task Category | Reason |
|--------------|--------|
| Docker CE installation | Requires Docker-in-Docker |
| UFW/iptables firewall | Requires kernel access |
| systemd user services | Requires running systemd (loginctl) |
| Clawdbot app installation | Package renaming pending |

#### Tasks That Run Normally

All other tasks execute as they would on a real system:
- ✅ System package installation (35+ packages via apt)
- ✅ User creation and configuration
- ✅ Node.js and pnpm installation
- ✅ Directory structure creation
- ✅ Configuration file rendering (.bashrc, sudoers, vim, git)
- ✅ SSH directory setup

### Implementation

Tasks are conditionally skipped using Ansible's `when` directive:

```yaml
# Example: Skip Docker installation in CI mode
- name: Include Docker installation tasks
  ansible.builtin.include_tasks: docker-linux.yml
  when: not ci_test

# Example: Skip systemd setup in CI mode
- name: Enable lingering for clawdbot user
  ansible.builtin.command: loginctl enable-linger {{ clawdbot_user }}
  when: ansible_os_family == 'Debian' and not ci_test
```

## Test Coverage

### What Gets Tested

| Component | Tested? | Coverage |
|-----------|---------|----------|
| System packages | ✅ Yes | All 35+ packages installed and verified |
| User creation | ✅ Yes | User exists, home directory, shell |
| User configuration | ✅ Yes | .bashrc, .bash_profile, PATH setup |
| Sudo permissions | ✅ Yes | sudoers file exists and validates |
| SSH setup | ✅ Yes | .ssh directory with correct permissions |
| Node.js installation | ✅ Yes | Version 22.x installed and verified |
| pnpm installation | ✅ Yes | Global install + version check |
| pnpm configuration | ✅ Yes | Global dir and bin dir set correctly |
| Directory structure | ✅ Yes | All .clawdbot/* dirs with permissions |
| Credentials directory | ✅ Yes | Mode 0700 enforced |
| Git global config | ✅ Yes | Aliases and default branch |
| Vim configuration | ✅ Yes | /etc/vim/vimrc.local template |
| Docker CE | ❌ No | Requires Docker-in-Docker |
| UFW firewall | ❌ No | Requires kernel access |
| systemd services | ❌ No | Requires running systemd |
| Tailscale | ❌ No | Disabled by default |
| Clawdbot app | ❌ No | Package renaming pending |

**Coverage: ~75%** of playbook tasks are validated by the test harness.

### Idempotency Improvements

The test harness revealed and fixed several idempotency issues:

#### pnpm Installation
**Before:**
```yaml
- name: Install pnpm globally
  ansible.builtin.command: npm install -g pnpm
  args:
    creates: /usr/local/bin/pnpm  # Path was incorrect
```

**After:**
```yaml
- name: Check if pnpm is already installed
  ansible.builtin.command: pnpm --version
  register: pnpm_check
  failed_when: false
  changed_when: false

- name: Install pnpm globally
  ansible.builtin.command: npm install -g pnpm
  when: pnpm_check.rc != 0
```

#### pnpm Configuration
**Before:**
```yaml
- name: Configure pnpm for clawdbot user
  ansible.builtin.shell:
    cmd: |
      pnpm config set global-dir {{ clawdbot_home }}/.local/share/pnpm
      pnpm config set global-bin-dir {{ clawdbot_home }}/.local/bin
  changed_when: true  # Always reports changed!
```

**After:**
```yaml
- name: Configure pnpm for clawdbot user
  ansible.builtin.shell:
    cmd: |
      CURRENT_GLOBAL_DIR=$(pnpm config get global-dir 2>/dev/null || echo "")
      CURRENT_BIN_DIR=$(pnpm config get global-bin-dir 2>/dev/null || echo "")
      CHANGED=0
      if [ "$CURRENT_GLOBAL_DIR" != "{{ clawdbot_home }}/.local/share/pnpm" ]; then
        pnpm config set global-dir {{ clawdbot_home }}/.local/share/pnpm
        CHANGED=1
      fi
      if [ "$CURRENT_BIN_DIR" != "{{ clawdbot_home }}/.local/bin" ]; then
        pnpm config set global-bin-dir {{ clawdbot_home }}/.local/bin
        CHANGED=1
      fi
      exit $CHANGED
  register: pnpm_config_result
  changed_when: pnpm_config_result.rc == 1
  failed_when: pnpm_config_result.rc > 1
```

## Test Workflow

### Local Development

```bash
# 1. Make changes to the playbook
vim roles/clawdbot/tasks/main.yml

# 2. Run tests to validate
bash tests/run-tests.sh

# 3. Fix any failures and re-test
bash tests/run-tests.sh
```

### Test Execution Flow

```
┌─────────────────────────────────────┐
│  run-tests.sh                       │
│  • Builds Docker image              │
│  • Runs container                   │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Container: entrypoint.sh           │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Step 1: Convergence                │
│  ansible-playbook playbook.yml      │
│    -e ci_test=true                  │
│    -e ansible_become=false          │
│    --connection=local               │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Step 2: Verification               │
│  ansible-playbook tests/verify.yml  │
│  • Check user exists                │
│  • Check packages installed         │
│  • Check directories created        │
│  • Check configs rendered           │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  Step 3: Idempotency                │
│  ansible-playbook playbook.yml      │
│    (second run)                     │
│  • Parse output for "changed=N"     │
│  • Assert N == 0                    │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  All tests passed ✓                 │
└─────────────────────────────────────┘
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | Test failure (convergence, verification, or idempotency) |

## Troubleshooting

### Build Failures

**Symptom:** Docker build fails
```bash
ERROR: failed to solve: failed to fetch ...
```

**Solution:** Check network connectivity and Docker daemon status
```bash
docker info
docker build -t test -f tests/Dockerfile.ubuntu2404 .
```

### Convergence Failures

**Symptom:** Playbook fails during execution
```bash
TASK [some-task] ***
fatal: [localhost]: FAILED! => ...
```

**Solution:** Run playbook manually in container for debugging
```bash
docker build -t test -f tests/Dockerfile.ubuntu2404 .
docker run --rm -it test bash
# Inside container:
ansible-playbook playbook.yml -e ci_test=true -e ansible_become=false --connection=local
```

### Verification Failures

**Symptom:** Assertions fail in verify.yml
```bash
TASK [Assert directories exist] ***
fatal: [localhost]: FAILED! => {"assertion": ..., "failed": true}
```

**Solution:** Check what state the playbook actually created
```bash
docker run --rm -it test bash -c "
  ansible-playbook playbook.yml -e ci_test=true --connection=local > /dev/null
  ls -la /home/clawdbot/.clawdbot/
  dpkg -l | grep nodejs
"
```

### Idempotency Failures

**Symptom:** Second run shows changed > 0
```bash
===> Idempotency: FAILED (changed=2)
```

**Solution:** Identify which tasks are not idempotent
```bash
# Run with verbose output to see which tasks changed
docker run --rm test bash -c "
  ansible-playbook playbook.yml -e ci_test=true --connection=local > /dev/null
  ansible-playbook playbook.yml -e ci_test=true --connection=local -v 2>&1 | grep 'changed:'
"
```

Common idempotency issues:
- Tasks using `shell` or `command` without `changed_when`
- File operations without `creates` or proper state checking
- Package installations that don't check if already installed

## Adding New Tests

### Testing Additional Distributions

To add support for another distribution (e.g., Debian 12):

1. **Create Dockerfile**
```bash
# tests/Dockerfile.debian12
FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y ansible python3 python3-apt sudo git curl && \
    apt-get clean

COPY . /opt/ansible
WORKDIR /opt/ansible

RUN ansible-galaxy collection install -r requirements.yml

ENTRYPOINT ["bash", "tests/entrypoint.sh"]
```

2. **Run tests**
```bash
bash tests/run-tests.sh debian12
```

### Adding Verification Checks

To add new assertions to `verify.yml`:

```yaml
- name: Verify custom configuration
  ansible.builtin.stat:
    path: /path/to/config
  register: config_check

- name: Assert config exists
  ansible.builtin.assert:
    that:
      - config_check.stat.exists
      - config_check.stat.mode == '0644'
    fail_msg: "Configuration file missing or has wrong permissions"
```

## CI/CD Integration

### GitHub Actions

Example workflow for running tests in CI:

```yaml
name: Test Playbook

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run Docker-based tests
        run: bash tests/run-tests.sh ubuntu2404

      - name: Upload test logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs
          path: /tmp/test-output.log
```

### GitLab CI

```yaml
test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - bash tests/run-tests.sh ubuntu2404
  only:
    - merge_requests
    - main
```

## Performance

**Typical test run time:** 3-5 minutes

Breakdown:
- Docker build: 60-90 seconds (cached layers: ~10 seconds)
- Convergence: 90-120 seconds
- Verification: 10-15 seconds
- Idempotency: 60-90 seconds

**Optimization tips:**
- Use Docker layer caching for faster builds
- Run tests in parallel for multiple distributions
- Cache apt packages in the Docker image

## Future Improvements

Potential enhancements to the test harness:

1. **Systemd support**: Use `systemd` container images to test daemon installation
2. **Multi-distribution matrix**: Test on Ubuntu 22.04, 24.04, Debian 11, 12
3. **Integration tests**: Test actual clawdbot app functionality (requires package)
4. **Security scanning**: Run ansible-lint, yamllint, and security scanners
5. **Performance benchmarks**: Track playbook execution time over commits
6. **Molecule integration**: Migrate to Ansible Molecule for more advanced testing

## Related Documentation

- [Installation Guide](installation.md) - Manual playbook installation
- [Development Mode](development-mode.md) - Building clawdbot from source
- [Architecture](architecture.md) - System design and components
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
