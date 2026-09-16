#!/usr/bin/env bash
set -euo pipefail

# Run only in a disposable Linux container/VM: the fixture uses real sudo.
if [ "$EUID" -ne 0 ] || [ "$(uname -s)" != Linux ]; then
    echo "Run this test as root in a disposable Linux container/VM." >&2
    exit 1
fi

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export INSTALLER_TEST_ANSIBLE
INSTALLER_TEST_ANSIBLE=$(command -v ansible-playbook)
export INSTALLER_TEST_PLAYBOOK="$REPO_DIR/tests/installer-user.yml"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/local/playbooks" "$TEST_DIR/collection"
touch "$TEST_DIR/local/playbooks/install.yml"

# Replace acquisition and route the entrypoint's exact arguments to a small
# playbook. Ansible itself and its privilege switching are not mocked.
cat > "$TEST_DIR/bin/ansible-galaxy" <<'EOF'
#!/usr/bin/env bash
echo 'openclaw.installer 1.0.0'
EOF
cat > "$TEST_DIR/bin/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exec "$INSTALLER_TEST_ANSIBLE" "$INSTALLER_TEST_PLAYBOOK" "${@:2}"
EOF
chmod +x "$TEST_DIR/bin/ansible-galaxy" "$TEST_DIR/bin/ansible-playbook"
export PATH="$TEST_DIR/bin:$PATH"

FAILED=0
for ENTRYPOINT in local collection bootstrap; do
    echo "===> Root installer user switching: $ENTRYPOINT"
    if [ "$ENTRYPOINT" = bootstrap ]; then
        SCRIPT="$REPO_DIR/install.sh"
        cd "$TEST_DIR/collection"
    else
        SCRIPT="$REPO_DIR/run-playbook.sh"
        cd "$TEST_DIR/$ENTRYPOINT"
    fi
    if ! bash "$SCRIPT" -e '{"installer_test_value":"value with spaces"}'; then
        FAILED=1
    fi
done
exit "$FAILED"
