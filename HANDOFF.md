# HANDOFF.md - Remove macOS Support Branch

## Quick Summary

- **What happened**: macOS support removed (commit `a1c9b7d`, 2026-02-06)
- **Why**: Security risks of system-level modifications on primary host OS
- **Branch**: `remove-macos-support`
- **Status**: Code complete, needs documentation cleanup
- **CI tests**: Located in `tests/`, working but limited scope (skips 37 tasks)

## What Needs to Be Done

### Documentation Updates (30 min)

Update these files to reflect that macOS support has been **removed**, not "coming soon" or "partially supported":

- [ ] **CHANGELOG.md**
  - Line 8: Remove "Added macOS support" claim
  - Line 223: Change macOS from "✅ Working" to "❌ Removed (security concerns)"
  - Lines 275-284: Rewrite "Known Issues - macOS Limitations" to explain removal instead of limitations
  - Consider adding v2.0.1 section documenting the removal

- [ ] **AGENTS.md**
  - Line 156: Change "Incomplete support (no launchd, basic firewall)" to "Support removed as of 2026-02-06 due to security concerns. See HANDOFF.md and GitHub issue for restoration path."

- [ ] **UPGRADE_NOTES.md**
  - Lines 164-172: Rename section from "TODO - Future macOS Enhancements" to "macOS Support - Removed"
  - Add explanation: why removed, what was removed, link to GitHub issue
  - Remove the "Current macOS Status" checklist implying work is in progress

- [ ] **RELEASE_NOTES_v2.0.0.md**
  - Line 110: Add note after "macOS framework ready": "**UPDATE (2026-02-06)**: macOS support was subsequently removed due to security concerns. See GitHub issue for restoration roadmap."

**Verification**: Run `git diff` after updates to ensure changes are accurate and complete.

### Create GitHub Issue (15 min)

- [ ] Create issue titled "Restore macOS Support with Security Hardening"
- [ ] Use the template provided in the "GitHub Issue Template" section below
- [ ] Label with: `enhancement`, `security`, `macOS`
- [ ] Link to this HANDOFF.md in the issue description

## CI Test Harness Info

**Location**: `tests/` directory

**What it does**: Tests the Ansible playbook in isolated Docker containers (Ubuntu 24.04) to validate most tasks work correctly.

**Coverage**: ~75% of playbook tasks validated
- ✅ System packages installation (35+ packages)
- ✅ User creation and configuration
- ✅ Sudoers scoped permissions
- ✅ Node.js and pnpm installation
- ✅ Directory structure with correct permissions
- ✅ Git and Vim configurations
- ✅ Idempotency checks (second run = 0 changes)

**Limitations**: Skips 37 tasks due to Docker constraints
- ❌ Docker CE installation (Docker-in-Docker not possible)
- ❌ UFW/iptables firewall (needs kernel access)
- ❌ systemd services (container lacks systemd)
- ❌ Clawdbot binary install (external package, not in CI scope)

**Usage**: `./tests/run-tests.sh ubuntu2404`

**Why it matters**: Provides fast feedback on most playbook logic without requiring a full VM. Full end-to-end validation still needs bare metal or VM testing.

## macOS Restoration Context

**What was deleted** (commit `a1c9b7d`):
- `roles/clawdbot/tasks/firewall-macos.yml`
- `roles/clawdbot/tasks/system-tools-macos.yml`
- `roles/clawdbot/tasks/docker-macos.yml`
- `roles/clawdbot/tasks/tailscale-macos.yml`

**How to recover**: `git show a1c9b7d^:roles/clawdbot/tasks/firewall-macos.yml`

**Main challenge**: Linux has 8-layer security hardening. macOS needs equivalent protections:
- UFW → pf (Packet Filter) - **HARD** (complex rule syntax, Docker Desktop integration)
- fail2ban → sshguard or custom - **MEDIUM**
- DOCKER-USER iptables chain → pf + Docker Desktop - **HARD**
- systemd hardening → launchd sandboxing - **MEDIUM**
- Auto-updates → softwareupdate - **MEDIUM**

**Reference**: `docs/security.md` documents current Linux security architecture

**Bottom line**: Restoration requires deep knowledge of macOS pf firewall and Docker Desktop networking to achieve equivalent security isolation.

## GitHub Issue Template

Copy this template when creating the GitHub issue:

```markdown
# Restore macOS Support with Security Hardening

## Why It Was Removed

macOS support removed in commit `a1c9b7d` (2026-02-06) due to security concerns:

> "system-level permissions and configurations introduce significant security risks when executed on a primary host OS."

The Linux version has robust 8-layer security hardening. The macOS implementation lacked equivalent protections, particularly around firewall isolation and Docker container port exposure.

## What Was Removed

**Deleted files**:
- `roles/clawdbot/tasks/firewall-macos.yml`
- `roles/clawdbot/tasks/system-tools-macos.yml`
- `roles/clawdbot/tasks/docker-macos.yml`
- `roles/clawdbot/tasks/tailscale-macos.yml`

**Removed features**:
- macOS OS detection in `playbook.yml`
- Homebrew and zsh configuration
- Application Firewall basic setup

**Recovery**: Use `git show a1c9b7d^:roles/clawdbot/tasks/[filename]` to view deleted files.

## Security Requirements

Linux has 8 security layers. macOS restoration requires implementing equivalents:

| Linux Layer | macOS Equivalent | Difficulty |
|-------------|------------------|------------|
| UFW firewall | pf (Packet Filter) | **HARD** |
| fail2ban SSH protection | sshguard or custom | MEDIUM |
| DOCKER-USER iptables chain | pf + Docker Desktop API | **HARD** |
| systemd service hardening | launchd sandboxing | MEDIUM |
| unattended-upgrades | softwareupdate automation | MEDIUM |
| Scoped sudoers | Same approach | EASY |
| localhost-only Docker ports | Same approach | EASY |
| Non-root containers | Same approach | EASY |

**Critical challenges**:
1. **pf firewall + Docker Desktop**: Need to prevent containers from exposing ports externally while allowing localhost access. Docker Desktop on macOS uses VM networking, making this complex.
2. **Port isolation**: Must achieve same result as Linux DOCKER-USER chain: external port scan shows only SSH open, Docker containers inaccessible from internet.

## To Restore

**Phase 1: Research** (2-4 hours)
- [ ] Study pf firewall syntax and Docker Desktop networking on macOS
- [ ] Research how Docker Desktop handles port forwarding on macOS
- [ ] Investigate if Docker Desktop API allows port binding restrictions
- [ ] Test if pf can block Docker-forwarded ports effectively

**Phase 2: Implementation** (4-8 hours)
- [ ] Restore 4 macOS task files from git history
- [ ] Implement pf firewall rules for SSH-only external access
- [ ] Configure Docker Desktop for localhost-only port binding
- [ ] Implement sshguard or equivalent for SSH protection
- [ ] Add softwareupdate automation
- [ ] Configure launchd service with sandboxing

**Phase 3: Testing** (2-4 hours)
- [ ] Test on real macOS hardware (VM not sufficient for Docker Desktop)
- [ ] Run external port scan: only SSH should be open
- [ ] Verify Docker containers can't expose ports externally
- [ ] Test Docker containers can communicate on localhost
- [ ] Create macOS-specific CI tests (if possible)

**Phase 4: Documentation** (1-2 hours)
- [ ] Update security.md with macOS security architecture
- [ ] Document pf firewall rules and rationale
- [ ] Update CHANGELOG.md and AGENTS.md
- [ ] Add troubleshooting guide for macOS-specific issues

## Success Criteria

- [ ] External port scan (from different machine) shows only port 22 open
- [ ] Docker containers cannot expose ports to external network
- [ ] Docker containers can communicate via localhost (127.0.0.1)
- [ ] SSH protected by automated blocking (sshguard or equivalent)
- [ ] System updates automated
- [ ] Security audit confirms equivalent protection to Linux version
- [ ] Documentation clearly explains security architecture
- [ ] CI tests pass on macOS (if feasible)

## References

- **Current security architecture**: `docs/security.md`
- **Removal commit**: `a1c9b7d` (2026-02-06)
- **Original macOS addition**: Check git history before removal
- **pf documentation**: https://www.openbsd.org/faq/pf/
- **launchd documentation**: https://www.manpagez.com/man/5/launchd.plist/
- **Docker Desktop networking**: https://docs.docker.com/desktop/networking/

## Estimated Effort

**Total**: 10-20 hours of focused work by someone with:
- Deep knowledge of macOS networking and pf firewall
- Experience with Docker Desktop on macOS
- Understanding of security hardening principles
- Access to real macOS hardware for testing

**Not recommended for**: Junior developers or those unfamiliar with packet filtering and network security.
```

## Quick Reference

### Files Needing Updates

```
Documentation files:
- CHANGELOG.md (lines 8, 223, 275-284)
- AGENTS.md (line 156)
- UPGRADE_NOTES.md (lines 164-172)
- RELEASE_NOTES_v2.0.0.md (line 110)
```

### CI Test Files

```
Test harness files:
- tests/Dockerfile.ubuntu2404
- tests/entrypoint.sh
- tests/verify.yml
- tests/run-tests.sh
```

### Deleted macOS Files

```
Recoverable from git history:
- roles/clawdbot/tasks/firewall-macos.yml
- roles/clawdbot/tasks/system-tools-macos.yml
- roles/clawdbot/tasks/docker-macos.yml
- roles/clawdbot/tasks/tailscale-macos.yml
```

## Notes for Coworker

1. **Focus on documentation first**: Update all 4 docs files before considering any code changes.

2. **Don't restore macOS hastily**: The removal was deliberate. Restoration requires solving hard security problems (pf + Docker Desktop).

3. **CI tests are good enough**: Don't try to force 100% coverage in Docker. The 37 skipped tasks require VM/bare metal.

4. **Security is non-negotiable**: Any macOS restoration must achieve equivalent protection to the Linux version. No shortcuts.

5. **Use the GitHub issue**: The detailed template provides a complete roadmap. Don't start coding without a clear plan.

6. **Questions?**: Check git history (`git log --oneline --all`), read `docs/security.md`, or ask for clarification.

---

**Created**: 2026-02-06
**Branch**: `remove-macos-support`
**Next step**: Update documentation files listed above
