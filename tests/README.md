# Docker CI Test Harness

This directory contains a Docker-based CI test harness for the Ansible playbook. It validates convergence, correctness, and idempotency by running the playbook inside an Ubuntu 24.04 container.

## Quick Start

```bash
# Run all tests
bash tests/run-tests.sh

# Or specify a distro (currently only ubuntu2404 available)
bash tests/run-tests.sh ubuntu2404
```

## Test Structure

The test harness runs three sequential tests:

1. **Convergence**: Runs the playbook with `ci_test=true` to verify it completes without errors
2. **Verification**: Runs `verify.yml` to assert the system is in the expected state
3. **Idempotency**: Runs the playbook a second time and verifies `changed=0`

## Files

- `Dockerfile.ubuntu2404` - Ubuntu 24.04 container with Ansible pre-installed
- `entrypoint.sh` - Test execution script (convergence → verification → idempotency)
- `verify.yml` - Post-convergence assertions (user exists, packages installed, directories created, etc.)
- `run-tests.sh` - Local test runner script

## CI Test Mode

The `ci_test` variable skips tasks that require:
- Docker-in-Docker (Docker CE installation)
- Kernel access (UFW/iptables firewall)
- systemd services (loginctl, daemon installation)
- External package installation (clawdbot app install)

Everything else runs normally: package installation, user creation, Node.js/pnpm setup, directory structure, config file rendering, etc.

## What Gets Tested

| Component | Tested? | Notes |
|-----------|---------|-------|
| System packages (35+) | ✅ Yes | Full apt install |
| User creation + config | ✅ Yes | User, .bashrc, sudoers, SSH dir |
| Node.js + pnpm | ✅ Yes | Full install + version check |
| Directory structure | ✅ Yes | All .clawdbot/* dirs with perms |
| Git global config | ✅ Yes | Aliases, default branch |
| Vim config | ✅ Yes | Template rendering |
| Docker CE install | ❌ No | Needs Docker-in-Docker |
| UFW / iptables | ❌ No | Needs kernel access |
| fail2ban / systemd | ❌ No | Needs running systemd |
| Tailscale | ❌ No | Disabled by default already |
| Clawdbot app install | ❌ No | Package renaming pending |
| Idempotency | ✅ Yes | Second run must have 0 changes |

## Exit Codes

- `0` - All tests passed
- `1` - Test failure (convergence failed, verification failed, or idempotency check failed)

## Development

To add tests for additional distributions:
1. Create `Dockerfile.<distro>` (e.g., `Dockerfile.debian12`)
2. Run: `bash tests/run-tests.sh <distro>`

The test harness automatically builds the image and runs the test suite.
