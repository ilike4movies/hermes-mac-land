#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — credentialed downstream gates after RAL-800/799
#
# Runs (in order):
#   0. RAL-793 run inspect (optional; when HERMES_RUN_ID set or HERMES_AUTO_INSPECT_RAL793=1)
#   1. RAL-793 contract install (--post-linear)
#   2. governed stack-apply (moltbot main → .11; HERMES_AUTO_STACK_APPLY=0 to skip)
#   3. DISPATCH-NOW RAL-793 via Linear comment (default on; HERMES_AUTO_DISPATCH_RAL793=0 to skip)
#      stall_recovery=1 → two DISPATCH-NOW passes (~90s) to clear SLA-stale CLAIM then reopen
#      zombie reclaim (age≥1h) → three DISPATCH-NOW passes (~120s) for ultra-stale CLAIM
#      FAIL-CLOSED if AUTO_DISPATCH=1 and no DISPATCH-NOW post succeeds (needs LINEAR_API_KEY)
#   4. RAL-634 starvation verify (--post-linear)
#   5. optional inventory wait (stall default on) — poll run-inspect until evidence is real
#
# Machine status: posts STARTED/DONE/FAILED/PARTIAL to hermes-mac-land GitHub issue #1 when `gh` available (preflight skips beacon).
#
# Usage:
#   HERMES_AUTO_SURGICAL_LAND=0 curl -fsSL .../hermes-dispatcher-downstream.sh | bash
#   (auto-pins stall run + stack-apply=0 + stall_recovery=1 when run matches default;
#    .11 verified at #110 tip — set HERMES_AUTO_STACK_APPLY=1 only if host drifts)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
LOG="$DIR/dispatcher-downstream.log"
LINEAR_TICKET="${HERMES_RAL793_LINEAR_TICKET:-RAL-793}"
LINEAR_ISSUE_ID="${HERMES_RAL793_LINEAR_ISSUE_ID:-963472c8-cc84-426a-9ed6-79e08566353a}"
DEFAULT_STALL_RUN_ID="${HERMES_DEFAULT_STALL_RUN_ID:-20260826T232521106484Z-2954673}"

# Downstream-only: auto-pin stalled canary when HERMES_AUTO_SURGICAL_LAND=0 (#36 parity)
if [[ "${HERMES_AUTO_SURGICAL_LAND:-}" == "0" ]] && [[ -z "${HERMES_RUN_ID:-}" ]]; then
  export HERMES_RUN_ID="$DEFAULT_STALL_RUN_ID"
  echo "INFO: HERMES_RUN_ID defaulted to stalled canary run $HERMES_RUN_ID" >&2
fi

AUTO_DISPATCH="${HERMES_AUTO_DISPATCH_RAL793:-1}"
# Stall run: stack-apply defaults OFF — .11 verified at #110 tip (b3b82bf2… / a535cb7) @ 00:05Z.
if [[ "${HERMES_RUN_ID:-}" == "$DEFAULT_STALL_RUN_ID" ]]; then
  AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
  STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
  WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
else
  AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-1}"
  STALL_RECOVERY="${HERMES_STALL_RECOVERY:-}"
  WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-0}"
fi
AUTO_INSPECT="${HERMES_AUTO_INSPECT_RAL793:-}"
INSPECT_OUT="$DIR/ral793-inspect.out"
GH_STATUS_ISSUE="${HERMES_MAC_LAND_STATUS_ISSUE:-1}"
GH_STATUS_REPO="${HERMES_MAC_LAND_STATUS_REPO:-ilike4movies/hermes-mac-land}"
STARVE_RC=0
INVENTORY_RC=0
INVENTORY_WAIT_SECS="${HERMES_INVENTORY_WAIT_SECS:-900}"
INVENTORY_POLL_SECS="${HERMES_INVENTORY_POLL_SECS:-30}"

_contract="$DIR/hermes-ral793-contract-install.sh"
[[ -x "$_contract" ]] || _contract="$ROOT/shared-scripts/hermes-ral793-contract-install.sh"

_inspect="$DIR/hermes-ral793-run-inspect.sh"
[[ -x "$_inspect" ]] || _inspect="$ROOT/shared-scripts/hermes-ral793-run-inspect.sh"

_starve="$DIR/hermes-ral634-starvation-verify.sh"
[[ -x "$_starve" ]] || _starve="$ROOT/shared-scripts/hermes-ral634-starvation-verify.sh"

_stack_apply="$DIR/hermes-moltbot-stack-apply-via-ssh.sh"
[[ -x "$_stack_apply" ]] || _stack_apply="$ROOT/shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh"

_stall_age_secs() {
  local run_id="${1:-${HERMES_RUN_ID:-}}"
  local prefix ts start now
  prefix="${run_id%%-*}"
  [[ "$prefix" =~ ^([0-9]{8}T[0-9]{6}) ]] || { echo 0; return 0; }
  ts="${BASH_REMATCH[1]}"
  if date -u -d "${ts}Z" +%s >/dev/null 2>&1; then
    start="$(date -u -d "${ts}Z" +%s)"
  elif date -u -j -f "%Y%m%dT%H%M%S" "$ts" +%s >/dev/null 2>&1; then
    start="$(date -u -j -f "%Y%m%dT%H%M%S" "$ts" +%s)"
  else
    echo 0
    return 0
  fi
  now="$(date -u +%s)"
  echo $(( now - start ))
}

_load_hermes_ssh_env() {
  local f key val
  for f in "${HOME}/.hermes/.env" /opt/moltbot/config/secrets.env "${HOME}/.openclaw/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*|HERMES_HOST_SSH_PRIVATE_KEY=*)
          key="${line%%=*}"
          val="${line#*=}"
          val="${val%\"}"; val="${val#\"}"
          val="${val%\'}"; val="${val#\'}"
          [[ -z "${!key:-}" ]] && export "$key=$val"
          ;;
      esac
    done < "$f"
  done
}

_has_ssh_key() {
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && return 0
  [[ -s "${DIR}/host-ssh-key" ]] && return 0
  [[ -f "${HOME}/.hermes/.env" ]] && grep -q '^HERMES_HOST_SSH_PRIVATE_KEY=' "${HOME}/.hermes/.env" 2>/dev/null && return 0
  return 1
}

_has_linear_key() {
  [[ -n "${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}" ]] && return 0
  return 1
}

_preflight_env() {
  local reason=""
  local oot=0
  if [[ "${COMPOSER_REPO_URL:-}" == *ooterverse* ]] || [[ "${COMPOSER_REPO_URL:-}" == *Ooterverse* ]]; then
    oot=1
  fi
  # Fail-fast only when the credentialed path is impossible.
  # Ooterverse COMPOSER_REPO_URL alone must NOT block: this override pod can still
  # reach .11 after Tailscale approve + HERMES_HOST_SSH_PRIVATE_KEY (wait-login path).
  if [[ -z "${TS_AUTHKEY:-}" ]] && ! _has_ssh_key; then
    if [[ "$oot" -eq 1 ]]; then
      reason="wrong_repo=Ooterverse + missing_secrets=TS_AUTHKEY+HERMES_HOST_SSH_PRIVATE_KEY"
    else
      reason="missing_secrets=TS_AUTHKEY+HERMES_HOST_SSH_PRIVATE_KEY (attach Runtime Secrets at boot)"
    fi
  elif [[ -z "${TS_AUTHKEY:-}" ]] && ! command -v tailscale >/dev/null 2>&1; then
    reason="missing_tailscale=TS_AUTHKEY unset and tailscale not installed"
  elif [[ "$oot" -eq 1 ]]; then
    echo "WARN preflight: COMPOSER_REPO_URL is Ooterverse; credentials present — allowing downstream" >&2
  fi
  if [[ -n "$reason" ]]; then
    echo "FAIL preflight: $reason" >&2
    echo "  COMPOSER_REPO_URL=${COMPOSER_REPO_URL:-unset}" >&2
    echo "  fix: start NEW cloud agent on hermes-mac-land with LEGACY Hermes .11 secrets" >&2
    echo "  or Mac Hermes: Right-click → Open HERMES-ONE-SHOT-UNBLOCK.command (not double-click)" >&2
    echo "  or: approve Tailscale AuthURL + add HERMES_HOST_SSH_PRIVATE_KEY on this pod" >&2
    return 1
  fi
  return 0
}

_post_github_status() {
  local body="$1"
  command -v gh >/dev/null 2>&1 || return 0
  gh issue comment "$GH_STATUS_ISSUE" --repo "$GH_STATUS_REPO" --body "$body" >/dev/null 2>&1 || true
}

_post_linear_comment() {
  local body="$1"
  local key="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
  [[ -n "$key" ]] || return 1
  python3 - "$key" "$LINEAR_TICKET" "${LINEAR_ISSUE_ID:-}" "$body" <<'PY' 2>/dev/null
import json, sys, urllib.request
key, ticket, issue_id, body = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
iid = issue_id.strip()
if not iid:
    q1 = {"query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id}}}", "variables": {"q": ticket}}
    req = urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q1).encode(),
        headers={"Content-Type": "application/json", "Authorization": key})
    with urllib.request.urlopen(req, timeout=12) as r:
        nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
    if not nodes:
        raise SystemExit(1)
    iid = nodes[0]["id"]
q2 = {"query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
      "variables": {"id": iid, "b": body}}
with urllib.request.urlopen(urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key}), timeout=12) as r:
    ok = (json.load(r).get("data") or {}).get("commentCreate", {}).get("success")
raise SystemExit(0 if ok else 1)
PY
}

# Return 0 if inventory evidence looks real (not missing / not placeholder "pending").
_inventory_evidence_ok() {
  local out="$1"
  if printf '%s\n' "$out" | grep -q 'evidence/RAL-793-inventory.md --- MISSING'; then
    return 1
  fi
  # Capture a short window after the inventory header.
  local snippet
  snippet="$(printf '%s\n' "$out" | awk '/evidence\/RAL-793-inventory.md/{flag=1; next} flag{print; if(++n>=12) exit}')"
  if [[ -z "$snippet" ]]; then
    return 1
  fi
  # Placeholder written by contract-install preflight is not evidence.
  if printf '%s\n' "$snippet" | grep -Eqi '^(pending|TODO|placeholder)[[:space:]]*$' \
     && ! printf '%s\n' "$snippet" | grep -Eqi 'EP0[4-9]|EP1[0-4]|artifact|workspace|allow_path|script|tts|remotion'; then
    return 1
  fi
  if printf '%s\n' "$snippet" | grep -Eqi 'EP0[4-9]|EP1[0-4]|artifact|workspace|/opt/moltbot|script|tts|remotion|inventory'; then
    return 0
  fi
  # Any non-trivial multi-line content beyond "pending" counts as progress.
  local lines
  lines="$(printf '%s\n' "$snippet" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$lines" -ge 3 ]]
}

_fetch_script() {
  local name="$1" dest="$2"
  local pin="${HERMES_MAC_LAND_PIN:-main}"
  echo "fetching $name from $pin" | tee -a "$LOG"
  curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${pin}/shared-scripts/$name" \
    -o "$dest"
  chmod +x "$dest"
}

if [[ ! -x "$_contract" ]]; then
  _fetch_script "hermes-ral793-contract-install.sh" "$DIR/hermes-ral793-contract-install.sh"
  _contract="$DIR/hermes-ral793-contract-install.sh"
fi

if [[ ! -x "$_inspect" ]]; then
  _fetch_script "hermes-ral793-run-inspect.sh" "$DIR/hermes-ral793-run-inspect.sh"
  _inspect="$DIR/hermes-ral793-run-inspect.sh"
fi

if [[ ! -x "$_starve" ]]; then
  _fetch_script "hermes-ral634-starvation-verify.sh" "$DIR/hermes-ral634-starvation-verify.sh"
  _starve="$DIR/hermes-ral634-starvation-verify.sh"
fi

if [[ ! -x "$_stack_apply" ]]; then
  _fetch_script "hermes-moltbot-stack-apply-via-ssh.sh" "$DIR/hermes-moltbot-stack-apply-via-ssh.sh"
