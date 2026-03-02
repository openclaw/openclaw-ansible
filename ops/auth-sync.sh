#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/common.sh
source "${SCRIPT_DIR}/common.sh"

provider="${OAUTH_PROVIDER:-openai-codex}"
profiles_raw="${PROFILES:-dev-main andrea}"
model_ref="${MODEL_REF:-openai-codex/gpt-5.3-codex}"

efra_env_file="${EFRA_ENV_FILE:-/home/efra/.env}"
if [[ -f "${efra_env_file}" ]]; then
  # shellcheck disable=SC1090
  source "${efra_env_file}"
fi

source_codex_home="${EFRA_CODEX_HOME:-/home/efra/.codex}"
default_auth="${EFRA_CODEX_AUTH_DEFAULT:-${source_codex_home}/auth.json}"
andrea_auth="${EFRA_CODEX_AUTH_ANDREA:-${source_codex_home}/auth-andrea.json}"

[[ "${provider}" == "openai-codex" ]] || die "auth-sync supports only OAUTH_PROVIDER=openai-codex"
[[ -f "${default_auth}" ]] || die "Missing default Codex auth file: ${default_auth}"

if [[ ! -f "${andrea_auth}" ]]; then
  log "Andrea auth file not found (${andrea_auth}); falling back to default credential."
  andrea_auth="${default_auth}"
fi

log "Syncing Codex credentials from ${source_codex_home} into OpenClaw profiles: ${profiles_raw}"

run_sudo env \
  PROFILES_RAW="${profiles_raw}" \
  DEFAULT_AUTH="${default_auth}" \
  ANDREA_AUTH="${andrea_auth}" \
  node - <<'NODE'
const fs = require("fs");
const path = require("path");
const cp = require("child_process");

function decodeJwtPayload(token) {
  try {
    const parts = String(token || "").split(".");
    if (parts.length < 2) {
      return null;
    }
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(Buffer.from(b64 + pad, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

function readCredential(filePath) {
  const raw = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const tokens = raw && raw.tokens ? raw.tokens : {};
  const access = tokens.access_token;
  const refresh = tokens.refresh_token;
  const accountId = tokens.account_id;
  if (typeof access !== "string" || !access || typeof refresh !== "string" || !refresh) {
    throw new Error(`Missing access/refresh token in ${filePath}`);
  }

  const accessPayload = decodeJwtPayload(access) || {};
  const idPayload = decodeJwtPayload(tokens.id_token) || {};

  const expSec = Number(accessPayload.exp);
  const expires = Number.isFinite(expSec) && expSec > 0 ? expSec * 1000 : Date.now() + 60 * 60 * 1000;
  const email =
    typeof idPayload.email === "string" && idPayload.email.trim() ? idPayload.email.trim() : "default";

  const credential = {
    type: "oauth",
    provider: "openai-codex",
    access,
    refresh,
    expires,
  };
  if (typeof accountId === "string" && accountId) {
    credential.accountId = accountId;
  }
  if (email !== "default") {
    credential.email = email;
  }

  return { credential, email };
}

function ensureDir(dirPath, uid, gid) {
  fs.mkdirSync(dirPath, { recursive: true, mode: 0o700 });
  fs.chownSync(dirPath, uid, gid);
}

function ensureProfileSkeleton(profileDir, uid, gid) {
  // Recursive mkdir can leave intermediate directories owned by root.
  // Ensure profile roots are writable by openclaw before model configuration.
  ensureDir(profileDir, uid, gid);
  ensureDir(path.join(profileDir, "agents"), uid, gid);
  ensureDir(path.join(profileDir, "agents", "main"), uid, gid);
}

function loadStore(storePath) {
  try {
    const parsed = JSON.parse(fs.readFileSync(storePath, "utf8"));
    if (!parsed || typeof parsed !== "object") {
      return { version: 1, profiles: {} };
    }
    if (!parsed.profiles || typeof parsed.profiles !== "object") {
      parsed.profiles = {};
    }
    if (typeof parsed.version !== "number") {
      parsed.version = 1;
    }
    return parsed;
  } catch {
    return { version: 1, profiles: {} };
  }
}

function writeStore(storePath, store, uid, gid) {
  ensureDir(path.dirname(storePath), uid, gid);
  fs.writeFileSync(storePath, `${JSON.stringify(store, null, 2)}\n`, { mode: 0o600 });
  fs.chownSync(storePath, uid, gid);
  fs.chmodSync(storePath, 0o600);
}

function resolveProfileDir(profileName) {
  if (profileName === "default" || profileName === "main") {
    return "/home/openclaw/.openclaw";
  }
  return `/home/openclaw/.openclaw-${profileName}`;
}

function collectAgentDirs(profileDir) {
  const dirs = new Set([path.join(profileDir, "agents", "main", "agent")]);
  const configPath = path.join(profileDir, "openclaw.json");

  try {
    const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
    const list = cfg && cfg.agents && Array.isArray(cfg.agents.list) ? cfg.agents.list : [];
    for (const item of list) {
      if (!item || typeof item !== "object") {
        continue;
      }
      if (typeof item.agentDir === "string" && item.agentDir.trim()) {
        dirs.add(item.agentDir.trim());
        continue;
      }
      const id = typeof item.id === "string" && item.id.trim() ? item.id.trim() : "main";
      dirs.add(path.join(profileDir, "agents", id, "agent"));
    }
  } catch {
    // Keep default main agent dir.
  }

  return Array.from(dirs);
}

const profilesRaw = process.env.PROFILES_RAW || "dev-main andrea";
const profiles = profilesRaw
  .split(/\s+/)
  .map((v) => v.trim())
  .filter(Boolean);

if (profiles.length === 0) {
  throw new Error("PROFILES_RAW resolved to an empty profile list.");
}

const defaultAuth = process.env.DEFAULT_AUTH;
const andreaAuth = process.env.ANDREA_AUTH || defaultAuth;
if (!defaultAuth) {
  throw new Error("DEFAULT_AUTH is required.");
}

const defaultCred = readCredential(defaultAuth);
const andreaCred = readCredential(andreaAuth);

const uid = Number(cp.execSync("id -u openclaw", { encoding: "utf8" }).trim());
const gid = Number(cp.execSync("id -g openclaw", { encoding: "utf8" }).trim());

const codexDir = "/home/openclaw/.codex";
ensureDir(codexDir, uid, gid);
for (const [src, name] of [
  [defaultAuth, "auth.json"],
  [andreaAuth, "auth-andrea.json"],
]) {
  fs.copyFileSync(src, path.join(codexDir, name));
  fs.chownSync(path.join(codexDir, name), uid, gid);
  fs.chmodSync(path.join(codexDir, name), 0o600);
}

let stores = 0;
for (const profile of profiles) {
  const profileDir = resolveProfileDir(profile);
  const selected = profile === "andrea" ? andreaCred : defaultCred;
  ensureProfileSkeleton(profileDir, uid, gid);
  const agentDirs = collectAgentDirs(profileDir);

  for (const agentDir of agentDirs) {
    ensureDir(agentDir, uid, gid);
    const storePath = path.join(agentDir, "auth-profiles.json");
    const store = loadStore(storePath);
    store.version = 1;
    if (!store.profiles || typeof store.profiles !== "object") {
      store.profiles = {};
    }

    store.profiles["openai-codex:default"] = selected.credential;
    if (!store.order || typeof store.order !== "object") {
      store.order = {};
    }

    if (selected.email && selected.email !== "default") {
      const emailProfile = `openai-codex:${selected.email}`;
      store.profiles[emailProfile] = selected.credential;
      store.order["openai-codex"] = [emailProfile, "openai-codex:default"];
    } else {
      store.order["openai-codex"] = ["openai-codex:default"];
    }

    writeStore(storePath, store, uid, gid);
    stores += 1;
  }

  console.log(`Synced auth-profiles for profile=${profile} agentDirs=${agentDirs.length}`);
}

console.log(`SYNC_OK profiles=${profiles.length} stores=${stores}`);
NODE

for profile in ${profiles_raw}; do
  log "Configuring default model for profile=${profile} -> ${model_ref}"
  profile_env="/etc/openclaw/secrets/${profile}.env"
  run_sudo -u openclaw -H bash -lc \
    "set -euo pipefail; \
     export HOME=/home/openclaw; \
     export OPENCLAW_BUNDLED_PLUGINS_DIR=/home/openclaw/.openclaw/bundled-extensions; \
     if [[ -f '${profile_env}' ]]; then set -a; source '${profile_env}'; set +a; fi; \
     /home/openclaw/.local/bin/openclaw --profile '${profile}' models set '${model_ref}' >/dev/null; \
     /home/openclaw/.local/bin/openclaw --profile '${profile}' models status --plain"
done

log "Credential sync completed for profiles: ${profiles_raw}"
