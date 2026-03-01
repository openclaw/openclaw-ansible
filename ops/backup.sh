#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/common.sh
source "${SCRIPT_DIR}/common.sh"

need_cmd tar
need_cmd date

backup_root="${BACKUP_DIR:-${ROOT_DIR}/backups}"
timestamp="$(date +%Y%m%d-%H%M%S)"
archive_path="${backup_root}/openclaw-backup-${timestamp}.tar.gz"

mkdir -p "${backup_root}"

candidates=(
  "${ROOT_DIR}/inventories/dev/group_vars/all.yml"
  "${ROOT_DIR}/inventories/dev/group_vars/vault.yml"
  "/etc/openclaw"
  "/opt/openclaw/control-plane"
  "/home/efra/openclaw-control-plane"
  "/home/openclaw/.openclaw"
  "/home/openclaw/.openclaw-dev-main"
  "/home/openclaw/.openclaw-andrea"
  "/home/efra/.openclaw"
  "/home/efra/.openclaw-dev-main"
  "/home/efra/.openclaw-andrea"
  "/home/openclaw/.config/systemd/user/openclaw-gateway-dev-main.service"
  "/home/openclaw/.config/systemd/user/openclaw-gateway-andrea.service"
  "/home/efra/.config/systemd/user/openclaw-gateway-dev-main.service"
  "/home/efra/.config/systemd/user/openclaw-gateway-andrea.service"
)

existing=()
for path in "${candidates[@]}"; do
  if run_sudo test -e "${path}"; then
    existing+=("${path}")
  fi
done

(( ${#existing[@]} > 0 )) || die "No known OpenClaw paths found to backup."

log "Creating backup archive: ${archive_path}"
run_sudo tar -czf "${archive_path}" "${existing[@]}"

if [[ "$(id -u)" -ne 0 ]]; then
  run_sudo chown "$(id -u):$(id -g)" "${archive_path}" || true
fi

log "Backup completed with ${#existing[@]} paths."
log "Archive ready: ${archive_path}"
