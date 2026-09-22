#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/playbooks"
touch "$TEST_DIR/playbooks/install.yml"

# Exercise the public wrapper without provisioning the host or invoking sudo.
cat > "$TEST_DIR/bin/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exit "${INSTALLER_TEST_EXIT:-0}"
EOF
cat > "$TEST_DIR/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TEST_DIR/bin/ansible-playbook" "$TEST_DIR/bin/sudo"
export PATH="$TEST_DIR/bin:$PATH"
cd "$TEST_DIR"

bash "$REPO_DIR/run-playbook.sh" -e openclaw_user=custom-user > success.log
grep -Fq 'sudo su - custom-user' success.log
grep -Fq 'openclaw onboard --install-daemon' success.log
if grep -Fq 'config.yml' success.log; then
    echo 'Completion instructions still reference the retired configuration file.' >&2
    exit 1
fi

rc=0
INSTALLER_TEST_EXIT=42 bash "$REPO_DIR/run-playbook.sh" > failure.log 2>&1 || rc=$?
if [ "$rc" -ne 42 ] || grep -Fq 'INSTALLATION COMPLETE' failure.log; then
    echo 'A failed playbook must preserve its exit code without printing success.' >&2
    exit 1
fi
echo 'Installer completion output: PASSED'
