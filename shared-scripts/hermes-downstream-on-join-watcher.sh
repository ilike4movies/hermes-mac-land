#!/usr/bin/env bash
# Poll until Tailscale Running AND host SSH key present, then run downstream once.
# Does not mark done while secrets are still missing (avoids one-shot race after approve).
# Tip #140: when Running but host SSH still missing, beacon once to GitHub #1 / Linear RAL-823
# so approve-without-secrets is visible (Mac ONE-SHOT still preferred).
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$DIR/host-ssh-key}"
SECRETS_ENV="${HERMES_CLOUD_SECRETS_ENV:-$DIR/secrets.env}"
export HERMES_AUTO_SURGICAL_LAND=0
export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
export HERMES_CLOUD_APPLY_DIR="$DIR"
# Ooterverse pods inherit COMPOSER_REPO_URL=*ooterverse*; point downstream at hermes-mac-land.
export COMPOSER_REPO_URL="${HERMES_DOWNSTREAM_COMPOSER_REPO_URL:-github.com/ilike4movies/hermes-mac-land}"
marker="$DIR/downstream-on-join.done"
[[ -f "$marker" ]] && exit 0

_reload() {
  if [[ -f "$SECRETS_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$SECRETS_ENV"; set +a
  fi
  if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -s "$HOST_KEY_FILE" ]]; then
    HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$HOST_KEY_FILE")"
    export HERMES_HOST_SSH_PRIVATE_KEY
  fi
  for _f in \
      /tmp/cursor/cloud-agent-secrets/HERMES_HOST_SSH_PRIVATE_KEY \
      /tmp/cursor-secrets/HERMES_HOST_SSH_PRIVATE_KEY \
      "$HOME/.cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY" \
      /opt/cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY; do
    if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$_f" ]]; then
      HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$_f")"
      export HERMES_HOST_SSH_PRIVATE_KEY
    fi
  done
  for _f in \
      "$DIR/linear-api-key" \
      /tmp/cursor/cloud-agent-secrets/LINEAR_API_KEY \
      /tmp/cursor-secrets/LINEAR_API_KEY \
      "$HOME/.cursor/secrets/LINEAR_API_KEY" \
      /opt/cursor/secrets/LINEAR_API_KEY; do
    if [[ -z "${LINEAR_API_KEY:-}" && -f "$_f" ]]; then
      LINEAR_API_KEY="$(tr -d '\r\n' < "$_f")"
      export LINEAR_API_KEY
    fi
  done
}

_host_ready() {
  _reload
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" || -s "$HOST_KEY_FILE" ]]
}


_beacon_secrets_ready_once() {
  local mark="$DIR/secrets-ready.beacon"
  [[ -f "$mark" ]] && return 0
  local authurl="" posted=0
  authurl="$(head -1 "$DIR/CURRENT_AUTHURL.txt" 2>/dev/null || true)"
  local body
  body=$(cat <<EOF
## Cloud secrets ready — approve Tailscale to launch Downstream

host=\`cursor-cloud\` user=\`ubuntu\`
agent=\`${CURSOR_AGENT_ID:-bc-01a02142}\`
state=NeedsLogin + HERMES_HOST_SSH_PRIVATE_KEY present

SSH/Linear keys arrived while Tailscale still NeedsLogin. Approve:
${authurl:-see tip CURRENT_AUTHURL.md}

Or Mac ONE-SHOT from tip. Expect \`## Downstream STARTED\` → \`DONE\` next.
EOF
)
  # GitHub #1 (gh → token curl). Often 403 on Ooterverse pods.
  # Tip #153: skip gh when GH_TOKEN_INVALID.flag; timeout gh.
  local _dir="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
  if command -v gh >/dev/null 2>&1 && [[ ! -f "${_dir}/GH_TOKEN_INVALID.flag" ]]; then
    if timeout "${HERMES_GH_BEACON_TIMEOUT_SECS:-8}" gh issue comment 1 --repo ilike4movies/hermes-mac-land --body "$body" >/dev/null 2>&1; then
      posted=1
    fi
  fi
  if [[ "$posted" != "1" ]]; then
    local tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
    if [[ -f "${_dir}/GH_TOKEN_INVALID.flag" ]]; then tok=""; fi
    if [[ -n "$tok" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
      local payload
      payload="$(SECRETS_BEACON_BODY="$body" python3 -c 'import json,os; print(json.dumps({"body": os.environ["SECRETS_BEACON_BODY"]}))')"
      if curl -fsS -X POST \
        -H "Authorization: Bearer ${tok}" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "https://api.github.com/repos/ilike4movies/hermes-mac-land/issues/1/comments" >/dev/null 2>&1; then
        posted=1
      fi
    fi
  fi
  # Linear RAL-823 when gh unavailable — secrets imply LINEAR_API_KEY may be present.
  if [[ "$posted" != "1" && "${HERMES_SECRETS_READY_LINEAR_BEACON:-1}" == "1" ]]; then
    local lkey="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
    local linear_ticket="${HERMES_SECRETS_READY_LINEAR_ISSUE:-RAL-823}"
    if [[ -n "$lkey" ]] && command -v python3 >/dev/null 2>&1; then
      if LINEAR_KEY="$lkey" LINEAR_TICKET="$linear_ticket" SECRETS_BEACON_BODY="$body" python3 - <<'PY' >/dev/null 2>&1
import json, os, urllib.request
key = os.environ["LINEAR_KEY"]
ticket = os.environ["LINEAR_TICKET"]
body = os.environ["SECRETS_BEACON_BODY"]
q1 = {
    "query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id identifier}}}",
    "variables": {"q": ticket},
}
req = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q1).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
with urllib.request.urlopen(req, timeout=8) as r:
    nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
if not nodes:
    raise SystemExit(1)
iid = nodes[0]["id"]
q2 = {
    "query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
    "variables": {"id": iid, "b": body},
}
req2 = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
urllib.request.urlopen(req2, timeout=8).read()
print("ok")
PY
      then
        posted=1
        echo "$(date -u +%FT%TZ) watcher: secrets-ready Linear beacon → ${linear_ticket}" | tee -a "$DIR/wait-login.log"
      fi
    fi
  fi
  date -u +%FT%TZ > "$mark"
  if [[ "$posted" == "1" ]]; then
    echo "$(date -u +%FT%TZ) watcher: posted secrets-ready beacon" | tee -a "$DIR/wait-login.log"
  else
    echo "$(date -u +%FT%TZ) watcher: secrets-ready beacon skipped (gh/token/Linear write unavailable)" | tee -a "$DIR/wait-login.log"
  fi
}


_beacon_running_no_ssh_once() {
  # Tip #140: Tailscale joined but Runtime Secrets still missing — wake operator once.
  local mark="$DIR/running-no-ssh.beacon"
  [[ -f "$mark" ]] && return 0
  local body
  body=$(cat <<EOF
## Cloud Tailscale Running — host SSH still missing

host=\`cursor-cloud\` user=\`ubuntu\`
agent=\`${CURSOR_AGENT_ID:-bc-01a02142}\`
state=Running + HERMES_HOST_SSH_PRIVATE_KEY **absent**

Approve succeeded, but this Ooterverse pod cannot SSH to \`.11\` without Runtime Secrets.

**Do one:**
1. Prefer Mac ONE-SHOT (has \`LINEAR_API_KEY\` locally) — tip \`HERMES-ONE-SHOT-UNBLOCK.command\`
2. Or inject Runtime Secrets here: \`HERMES_HOST_SSH_PRIVATE_KEY\` + \`LINEAR_API_KEY\` (prefer also \`TS_AUTHKEY\`)
3. Or LEGACY Hermes \`.11\` cloud agent with secrets at boot

Expect next: \`## Downstream STARTED\` → \`## Downstream DONE\` on this issue + RAL-793 inventory.
EOF
)
  local posted=0
  local _dir="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
  if command -v gh >/dev/null 2>&1 && [[ ! -f "${_dir}/GH_TOKEN_INVALID.flag" ]]; then
    if timeout "${HERMES_GH_BEACON_TIMEOUT_SECS:-8}" gh issue comment 1 --repo ilike4movies/hermes-mac-land --body "$body" >/dev/null 2>&1; then
      posted=1
    fi
  fi
  if [[ "$posted" != "1" ]]; then
    local tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
    if [[ -f "${_dir}/GH_TOKEN_INVALID.flag" ]]; then tok=""; fi
    if [[ -n "$tok" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
      local payload
      payload="$(RUNNING_NO_SSH_BODY="$body" python3 -c 'import json,os; print(json.dumps({"body": os.environ["RUNNING_NO_SSH_BODY"]}))')"
      if curl -fsS -X POST \
        -H "Authorization: Bearer ${tok}" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "https://api.github.com/repos/ilike4movies/hermes-mac-land/issues/1/comments" >/dev/null 2>&1; then
        posted=1
      fi
    fi
  fi
  # Always write MCP surface file so agents can post when gh/token blocked (Ooterverse).
  printf '%s\n' "$body" >"$DIR/RUNNING_NO_SSH_MCP_SURFACE_NEEDED.txt" 2>/dev/null || true
  if [[ "$posted" != "1" && "${HERMES_RUNNING_NO_SSH_LINEAR_BEACON:-1}" == "1" ]]; then
    local lkey="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
    local linear_ticket="${HERMES_RUNNING_NO_SSH_LINEAR_ISSUE:-RAL-823}"
    if [[ -n "$lkey" ]] && command -v python3 >/dev/null 2>&1; then
      if LINEAR_KEY="$lkey" LINEAR_TICKET="$linear_ticket" RUNNING_NO_SSH_BODY="$body" python3 - <<'PY' >/dev/null 2>&1
import json, os, urllib.request
key = os.environ["LINEAR_KEY"]
ticket = os.environ["LINEAR_TICKET"]
body = os.environ["RUNNING_NO_SSH_BODY"]
q1 = {
    "query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id identifier}}}",
    "variables": {"q": ticket},
}
req = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q1).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
with urllib.request.urlopen(req, timeout=8) as r:
    nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
if not nodes:
    raise SystemExit(1)
iid = nodes[0]["id"]
q2 = {
    "query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
    "variables": {"id": iid, "b": body},
}
req2 = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
urllib.request.urlopen(req2, timeout=8).read()
print("ok")
PY
      then
        posted=1
        echo "$(date -u +%FT%TZ) watcher: tip#140 running-no-ssh Linear beacon → ${linear_ticket}" | tee -a "$DIR/wait-login.log"
      fi
    fi
  fi
  date -u +%FT%TZ > "$mark"
  if [[ "$posted" == "1" ]]; then
    echo "$(date -u +%FT%TZ) watcher: tip#140 posted running-no-ssh beacon" | tee -a "$DIR/wait-login.log"
  else
    echo "$(date -u +%FT%TZ) watcher: tip#140 running-no-ssh beacon skipped (wrote RUNNING_NO_SSH_MCP_SURFACE_NEEDED.txt)" | tee -a "$DIR/wait-login.log"
  fi
}

while true; do
  st=$(sudo tailscale --socket="$SOCK" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  print(json.load(sys.stdin).get("BackendState") or "")
except Exception:
  print("")' || true)
  if [[ "$st" == "NeedsLogin" || "$st" == "NoState" || -z "$st" ]]; then
    if _host_ready; then
      _beacon_secrets_ready_once || true
    fi
  fi
  if [[ "$st" == "Running" ]]; then
    if ! _host_ready; then
      echo "$(date -u +%FT%TZ) watcher: Running but host SSH missing — waiting (tip#140 beacon)" | tee -a "$DIR/wait-login.log"
      _beacon_running_no_ssh_once || true
      sleep 30
      continue
    fi
    echo "$(date -u +%FT%TZ) watcher: Running + host SSH — tip#143/#133 single-flight downstream" | tee -a "$DIR/wait-login.log"
    # Tip #143: resolve once launcher via -f (+ CDN), not -x-only (0644 curl downloads).
    once=""
    for cand in \
      "$DIR/hermes-cloud-run-downstream-once.sh" \
      "$(dirname "$0")/hermes-cloud-run-downstream-once.sh" \
      "$(dirname "$0")/shared-scripts/hermes-cloud-run-downstream-once.sh"
    do
      if [[ -f "$cand" ]]; then
        chmod +x "$cand" 2>/dev/null || true
        once="$cand"
        break
      fi
    done
    if [[ -z "$once" ]]; then
      once="$DIR/hermes-cloud-run-downstream-once.sh"
      echo "$(date -u +%FT%TZ) watcher: tip#143 fetching hermes-cloud-run-downstream-once.sh" | tee -a "$DIR/wait-login.log"
      curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${HERMES_MAC_LAND_PIN:-main}/shared-scripts/hermes-cloud-run-downstream-once.sh" -o "$once" \
        || curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-run-downstream-once.sh" -o "$once" || true
      chmod +x "$once" 2>/dev/null || true
    fi
    if [[ -f "$once" ]]; then
      export HERMES_CLOUD_APPLY_DIR="$DIR"
      if bash "$once"; then
        echo "$(date -u +%FT%TZ) watcher: tip#133 downstream SUCCESS" | tee -a "$DIR/wait-login.log"
        exit 0
      fi
      echo "$(date -u +%FT%TZ) watcher: tip#133 downstream FAIL — retry (no success marker)" | tee -a "$DIR/wait-login.log"
      sleep 60
      continue
    fi
    echo "$(date -u +%FT%TZ) watcher: ERROR missing hermes-cloud-run-downstream-once.sh (tip#143)" | tee -a "$DIR/wait-login.log"
    sleep 60
    continue
  fi
  sleep 30
done
