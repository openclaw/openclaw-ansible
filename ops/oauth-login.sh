#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/common.sh
source "${SCRIPT_DIR}/common.sh"

provider="${OAUTH_PROVIDER:-openai-codex}"
profiles_raw="${PROFILES:-dev-main andrea}"

log "Starting interactive OAuth login for provider=${provider} profiles=${profiles_raw}"

for profile in ${profiles_raw}; do
  log "OAuth login for profile=${profile}"
  run_sudo -u openclaw -H bash -lc \
    "/home/openclaw/.local/bin/openclaw --profile '${profile}' models auth login --provider '${provider}'"
done

log "OAuth login flow completed for all profiles."
