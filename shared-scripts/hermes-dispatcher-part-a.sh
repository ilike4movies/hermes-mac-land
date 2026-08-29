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

# Tip #145: resolve helpers via -f (0644 curl downloads), not -x-only.
_contract="$DIR/hermes-ral793-contract-install.sh"
[[ -f "$_contract" ]] || _contract="$ROOT/shared-scripts/hermes-ral793-contract-install.sh"

_inspect="$DIR/hermes-ral793-run-inspect.sh"
[[ -f "$_inspect" ]] || _inspect="$ROOT/shared-scripts/hermes-ral793-run-inspect.sh"

_starve="$DIR/hermes-ral634-starvation-verify.sh"
[[ -f "$_starve" ]] || _starve="$ROOT/shared-scripts/hermes-ral634-starvation-verify.sh"

_stack_apply="$DIR/hermes-moltbot-stack-apply-via-ssh.sh"
[[ -f "$_stack_apply" ]] || _stack_apply="$ROOT/shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh"

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

_ts_running() {
  command -v tailscale >/dev/null 2>&1 || return 1
  local st
  st="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
  print(json.load(sys.stdin).get("BackendState") or "")
except Exception:
  print("")' 2>/dev/null || true)"
  [[ "$st" == "Running" ]]
}

_preflight_env() {
  local reason=""
  local oot=0
  if [[ "${COMPOSER_REPO_URL:-}" == *ooterverse* ]] || [[ "${COMPOSER_REPO_URL:-}" == *Ooterverse* ]]; then
    oot=1
  fi
  # Fail-fast only when the credentialed path is impossible.
  # Ooterverse COMPOSER_REPO_URL alone must NOT block once Tailscale is Running
  # (or TS_AUTHKEY) AND host SSH key is present — wait-login path on this override pod.
  if [[ -z "${TS_AUTHKEY:-}" ]] && ! _has_ssh_key; then
    if [[ "$oot" -eq 1 ]]; then
      reason="wrong_repo=Ooterverse + missing_secrets=TS_AUTHKEY+HERMES_HOST_SSH_PRIVATE_KEY"
    else
      reason="missing_secrets=TS_AUTHKEY+HERMES_HOST_SSH_PRIVATE_KEY (attach Runtime Secrets at boot)"
    fi
  elif [[ -z "${TS_AUTHKEY:-}" ]] && ! command -v tailscale >/dev/null 2>&1; then
    reason="missing_tailscale=TS_AUTHKEY unset and tailscale not installed"
  elif [[ "$oot" -eq 1 ]]; then
    if [[ -n "${TS_AUTHKEY:-}" ]] || _ts_running; then
      echo "WARN preflight: COMPOSER_REPO_URL is Ooterverse; mesh+creds present — allowing downstream" >&2
    else
      reason="wrong_repo=Ooterverse + Tailscale not Running (approve AuthURL first, then SSH key)"
    fi
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
  # Tip #156: timeout gh; curl+token fallback so Mac ONE-SHOT/STALL Downstream DONE
  # still lands on issue #1 when gh hangs/fails (obj5 + NAG unload depend on it).
  local body="$1"
  local posted=0
  local gh_to="${HERMES_GH_BEACON_TIMEOUT_SECS:-8}"
  if command -v gh >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
      if timeout "$gh_to" gh issue comment "$GH_STATUS_ISSUE" --repo "$GH_STATUS_REPO" --body "$body" >/dev/null 2>&1; then
        posted=1
      fi
    elif gh issue comment "$GH_STATUS_ISSUE" --repo "$GH_STATUS_REPO" --body "$body" >/dev/null 2>&1; then
      posted=1
    fi
  fi
  if [[ "$posted" != "1" ]]; then
    local tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
    if [[ -z "$tok" ]] && command -v gh >/dev/null 2>&1; then
      tok="$(timeout 5 gh auth token 2>/dev/null || true)"
    fi
    if [[ -n "$tok" ]] && command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
      local owner="${GH_STATUS_REPO%%/*}" name="${GH_STATUS_REPO#*/}" payload
      payload="$(STATUS_BODY="$body" python3 -c 'import json,os; print(json.dumps({"body": os.environ["STATUS_BODY"]}))')"
      if curl -fsS -X POST \
        -H "Authorization: Bearer ${tok}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        --max-time 15 \
        --data "$payload" \
        "https://api.github.com/repos/${owner}/${name}/issues/${GH_STATUS_ISSUE}/comments" >/dev/null 2>&1; then
        posted=1
      fi
    fi
  fi
  if [[ "$posted" == "1" ]]; then
    echo "OK GitHub status posted to ${GH_STATUS_REPO}#${GH_STATUS_ISSUE}"
  else
    echo "WARN GitHub status post failed for ${GH_STATUS_REPO}#${GH_STATUS_ISSUE} (gh/token unavailable)" >&2
  fi
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
