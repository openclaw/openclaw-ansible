#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/common.sh
source "${SCRIPT_DIR}/common.sh"

need_cmd curl
need_cmd docker
need_cmd sed
need_cmd grep

check_url() {
  local url="$1"
  run_sudo curl -fsS "${url}" >/dev/null
  log "Health OK: ${url}"
}

simulate_and_assert() {
  local ingress_port="$1"
  local control_port="$2"
  local profile_label="$3"
  local payload resp task_id tasks_json

  payload=$(cat <<JSON
{"text":"smoke test ${profile_label}","source":{"channel":"telegram","chatId":"local-sim","userId":"local-user"}}
JSON
)

  resp="$(run_sudo curl -fsS -X POST "http://127.0.0.1:${ingress_port}/ingress/simulate" -H "content-type: application/json" -d "${payload}")"
  task_id="$(printf '%s' "${resp}" | sed -n 's/.*"taskId":"\([^"]*\)".*/\1/p')"
  [[ -n "${task_id}" ]] || die "Could not extract taskId from response (${profile_label}): ${resp}"

  sleep 2
  tasks_json="$(run_sudo curl -fsS "http://127.0.0.1:${control_port}/tasks?limit=10")"
  printf '%s' "${tasks_json}" | grep -q "${task_id}" || die "Task ${task_id} not found in control API (${profile_label})."

  log "Queue flow OK (${profile_label}) taskId=${task_id}"
}

log "Checking docker compose stack status."
run_sudo docker compose -f /home/efra/openclaw-control-plane/efra-core/docker-compose.yml -p ocp-efra-core ps >/dev/null
run_sudo docker compose -f /home/efra/openclaw-control-plane/andrea/docker-compose.yml -p ocp-andrea ps >/dev/null

check_url "http://127.0.0.1:39101/health"
check_url "http://127.0.0.1:30101/health"
check_url "http://127.0.0.1:39111/health"
check_url "http://127.0.0.1:30111/health"

simulate_and_assert 30101 39101 "efra-core"
simulate_and_assert 30111 39111 "andrea"

log "Smoke checks completed successfully."
