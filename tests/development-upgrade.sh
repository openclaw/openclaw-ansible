#!/usr/bin/env bash
set -euo pipefail

# Requires the disposable Linux harness's openclaw user, Node.js, and pnpm.
if [ "$EUID" -ne 0 ] || [ "$(uname -s)" != Linux ]; then
    echo "Run this test as root in the disposable Linux installer harness." >&2
    exit 1
fi

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
chmod 0755 "$TEST_DIR"
mkdir -p "$TEST_DIR/source" "$TEST_DIR/home/code" "$TEST_DIR/home/.local/bin"
chown -R openclaw:openclaw "$TEST_DIR/home"

cat > "$TEST_DIR/source/package.json" <<'EOF'
{
  "name": "openclaw-upgrade-fixture",
  "version": "1.0.0",
  "bin": {"openclaw": "openclaw.sh"},
  "scripts": {"build": "mkdir -p dist && id -un > dist/build-user"}
}
EOF
cat > "$TEST_DIR/source/openclaw.sh" <<'EOF'
#!/bin/sh
echo 'OpenClaw upgrade fixture 1.0.0'
EOF
chmod 0755 "$TEST_DIR/source/openclaw.sh"
git -C "$TEST_DIR/source" init -b main
git -C "$TEST_DIR/source" add package.json openclaw.sh
git -C "$TEST_DIR/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -m fixture

# Reproduce the old root wrapper: the checkout and existing build output belong
# to root even though the parent home/code directory belongs to the service user.
DEV_REPO="$TEST_DIR/home/code/openclaw"
git clone "$TEST_DIR/source" "$DEV_REPO"
chown -R openclaw:openclaw "$TEST_DIR/source"
mkdir "$DEV_REPO/dist"
echo root > "$DEV_REPO/dist/build-user"
echo 'keep my local notes' > "$DEV_REPO/notes.txt"
chmod 0600 "$DEV_REPO/notes.txt"
echo 'outside checkout' > "$TEST_DIR/outside"
chmod 0600 "$TEST_DIR/outside"
ln -s "$TEST_DIR/outside" "$DEV_REPO/outside-link"

cat > "$TEST_DIR/playbook.yml" <<'EOF'
---
- name: Upgrade an existing root-owned development checkout
  hosts: localhost
  connection: local
  become: true
  gather_facts: false
  tasks:
    - name: Run the production development installer
      ansible.builtin.include_role:
        name: openclaw
        tasks_from: openclaw-development
EOF
python3 - "$TEST_DIR" > "$TEST_DIR/vars.json" <<'PY'
import json
import sys

root = sys.argv[1]
json.dump({
    "openclaw_user": "openclaw",
    "openclaw_home": root + "/home",
    "openclaw_repo_url": root + "/source",
    "openclaw_repo_branch": "main",
}, sys.stdout)
PY
ANSIBLE_ROLES_PATH="$REPO_DIR/roles" ansible-playbook "$TEST_DIR/playbook.yml" -e "@$TEST_DIR/vars.json"

test "$(cat "$DEV_REPO/dist/build-user")" = openclaw
test "$(stat -c %U "$DEV_REPO/.git/config")" = openclaw
test "$(cat "$DEV_REPO/notes.txt")" = 'keep my local notes'
test "$(stat -c %a "$DEV_REPO/notes.txt")" = 600
test -L "$DEV_REPO/outside-link"
test "$(stat -c %U "$TEST_DIR/outside")" = root
test "$(stat -c %a "$TEST_DIR/outside")" = 600
test "$(cat "$TEST_DIR/outside")" = 'outside checkout'
echo '===> Development upgrade: PASSED (unprivileged build, local files preserved, symlink target untouched)'
