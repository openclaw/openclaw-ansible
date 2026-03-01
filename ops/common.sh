#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '[ops] %s\n' "$*"
}

die() {
  printf '[ops] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
}

run_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

resolve_inventory() {
  local env_name="${ENV:-dev}"
  printf '%s' "${INVENTORY:-${ROOT_DIR}/inventories/${env_name}/hosts.yml}"
}

resolve_limit() {
  printf '%s' "${LIMIT:-zennook}"
}

resolve_ansible_bin() {
  printf '%s' "${ANSIBLE_PLAYBOOK_BIN:-ansible-playbook}"
}
