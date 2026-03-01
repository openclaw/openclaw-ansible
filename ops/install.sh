#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/common.sh
source "${SCRIPT_DIR}/common.sh"

ansible_bin="$(resolve_ansible_bin)"
inventory_file="$(resolve_inventory)"
limit_host="$(resolve_limit)"

need_cmd "${ansible_bin}"

[[ -f "${inventory_file}" ]] || die "Inventory not found: ${inventory_file}"

extra_args=()
if [[ -n "${ANSIBLE_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_args=( ${ANSIBLE_EXTRA_ARGS} )
fi

log "Running enterprise install (inventory=${inventory_file}, limit=${limit_host})."
"${ansible_bin}" \
  -i "${inventory_file}" \
  "${ROOT_DIR}/playbooks/enterprise.yml" \
  -l "${limit_host}" \
  --become \
  -e openclaw_control_plane_enabled=true \
  -e openclaw_control_plane_manage_stack=true \
  "${extra_args[@]}"

log "Running control-plane reconciliation playbook."
"${ansible_bin}" \
  -i "${inventory_file}" \
  "${ROOT_DIR}/playbooks/control-plane-only.yml" \
  -l "${limit_host}" \
  --become \
  -e openclaw_control_plane_enabled=true \
  -e openclaw_control_plane_manage_stack=true \
  "${extra_args[@]}"

log "Install completed."
