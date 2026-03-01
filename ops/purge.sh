#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/common.sh
source "${SCRIPT_DIR}/common.sh"

need_cmd docker

if [[ "${1:-}" != "--yes" ]]; then
  die "This command is destructive. Re-run with: ./ops/purge.sh --yes"
fi

log "Stopping/removing control-plane compose stacks (efra-core, andrea)."
for profile in efra-core andrea; do
  compose_file="/home/efra/openclaw-control-plane/${profile}/docker-compose.yml"
  project_name="ocp-${profile}"
  if run_sudo test -f "${compose_file}"; then
    run_sudo docker compose -f "${compose_file}" -p "${project_name}" down --remove-orphans --volumes || true
  fi
done

log "Stopping known OpenClaw gateway services (best effort)."
for user_name in openclaw efra; do
  if id "${user_name}" >/dev/null 2>&1; then
    run_sudo -u "${user_name}" bash -lc \
      "systemctl --user stop openclaw-gateway-dev-main.service openclaw-gateway-andrea.service >/dev/null 2>&1 || true"
  fi
done

run_sudo pkill -f "openclaw-gateway" || true

purge_paths=(
  "/opt/openclaw/control-plane"
  "/home/efra/openclaw-control-plane"
  "/home/openclaw/.openclaw"
  "/home/openclaw/.openclaw-dev-main"
  "/home/openclaw/.openclaw-andrea"
  "/home/efra/.openclaw"
  "/home/efra/.openclaw-dev-main"
  "/home/efra/.openclaw-andrea"
)

log "Removing OpenClaw runtime/state directories."
for path in "${purge_paths[@]}"; do
  if run_sudo test -e "${path}"; then
    run_sudo rm -rf "${path}"
    log "Removed: ${path}"
  fi
done

log "Purge complete."
log "Note: /etc/openclaw was intentionally preserved (secrets/config bootstrap)."
