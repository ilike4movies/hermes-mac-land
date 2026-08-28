#!/usr/bin/env bash
# hermes-moltbot-cloud-tailscale-join-and-apply.sh — Cloud Cursor path to join Tailscale + land tip
#
# Paths:
#   A) TS_AUTHKEY set → join with authkey, then via-ssh surgical land
#   B) Already authenticated (interactive login approved) → skip join, via-ssh land
#   C) --wait-login → print AuthURL and wait until BackendState=Running, then land
#
# Mid-wait secret reload (cloud agents): if secrets are injected after start, they
# may appear in HERMES_CLOUD_SECRETS_ENV / TS_AUTHKEY file paths rather than the
# frozen process environment. Reloaded each wait tick.
# After Running + HERMES_AUTO_SURGICAL_LAND=0: wait for host SSH key before
# downstream (secrets often arrive after Tailscale approve). Jump ping is
# warn-only on this path (direct host SSH).
#
# Usage:
#   TS_AUTHKEY=tskey-auth-... bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh
#   bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh --already-up
#   bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login
#   bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh --dry-run
#
# Do not use Slack rockets. Do not git reset --hard /opt/moltbot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JUMP_HOST="${HERMES_JUMP_HOST:-100.92.147.61}"
JUMP_SSH="${HERMES_JUMP_SSH:-ilike4@${JUMP_HOST}}"
WAIT_SECS="${HERMES_TAILSCALE_WAIT_SECS:-90}"
LOGIN_WAIT_SECS="${HERMES_TAILSCALE_LOGIN_WAIT_SECS:-3600}"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
SECRETS_ENV="${HERMES_CLOUD_SECRETS_ENV:-/tmp/hermes-cloud-apply/secrets.env}"
TS_KEY_FILE="${HERMES_TS_AUTHKEY_FILE:-/tmp/hermes-cloud-apply/ts-authkey}"
JUMP_KEY_FILE="${HERMES_JUMP_SSH_KEY_FILE:-/tmp/hermes-cloud-apply/jump-ssh-key}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-/tmp/hermes-cloud-apply/host-ssh-key}"
TS_UP_PIDFILE="${SCRIPT_DIR}/tailscale-up-wait.pid"
TS_UP_LOCK="${SCRIPT_DIR}/tailscale-up-wait.lock"
DRY_RUN=0
ALREADY_UP=0
WAIT_LOGIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --already-up) ALREADY_UP=1; shift ;;
    --wait-login) WAIT_LOGIN=1; shift ;;
    --wait-secs) WAIT_SECS="$2"; shift 2 ;;
    --ssh) JUMP_SSH="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,32p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

echo "== cloud-tailscale-join-and-apply dry_run=$DRY_RUN already_up=$ALREADY_UP wait_login=$WAIT_LOGIN jump=$JUMP_SSH =="

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would install/join Tailscale (authkey or interactive), wait for $JUMP_HOST, then:"
  echo "  HERMES_JUMP_SSH=$JUMP_SSH bash $SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"
  exit 0
fi

reload_cloud_secrets() {
  if [[ -f "$SECRETS_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$SECRETS_ENV"; set +a
  fi
  if [[ -z "${TS_AUTHKEY:-}" && -f "$TS_KEY_FILE" ]]; then
    TS_AUTHKEY="$(tr -d '\r\n' < "$TS_KEY_FILE")"
    export TS_AUTHKEY
  fi
  if [[ -z "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" && -f "$JUMP_KEY_FILE" ]]; then
    HERMES_JUMP_SSH_PRIVATE_KEY="$(cat "$JUMP_KEY_FILE")"
    export HERMES_JUMP_SSH_PRIVATE_KEY
  fi
  if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$HOST_KEY_FILE" ]]; then
    HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$HOST_KEY_FILE")"
    export HERMES_HOST_SSH_PRIVATE_KEY
  fi
  if [[ -z "${LINEAR_API_KEY:-}" && -f "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}" ]]; then
    LINEAR_API_KEY="$(tr -d '\r\n' < "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}")"
    export LINEAR_API_KEY
  fi
}


_host_ssh_ready() {
  reload_cloud_secrets
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && return 0
  [[ -s "$HOST_KEY_FILE" ]] && return 0
  return 1
}

wait_for_host_ssh_key() {
  local max="${HERMES_HOST_SSH_WAIT_SECS:-3600}" i=0
  if _host_ssh_ready; then
    echo "OK host SSH key already present"
    return 0
  fi
  echo "== waiting up to ${max}s for HERMES_HOST_SSH_PRIVATE_KEY / $HOST_KEY_FILE =="
  while (( i < max )); do
    reload_cloud_secrets
    if _host_ssh_ready; then
      echo "OK host SSH key arrived after ${i}s"
      return 0
    fi
    if (( i % 60 == 0 )); then
      echo "  t=${i}s still waiting for host SSH / Linear key files (Runtime Secrets)"
    fi
    sleep 15
    i=$((i + 15))
  done
  echo "ERROR: host SSH key not present after ${max}s" >&2
  return 1
}


ts() {
  if [[ -S "$SOCK" ]]; then
    sudo -n tailscale --socket="$SOCK" "$@" 2>/dev/null || tailscale --socket="$SOCK" "$@"
  else
    sudo -n tailscale "$@" 2>/dev/null || tailscale "$@"
  fi
}

backend_state() {
  ts status --json 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get("BackendState") or "")
except Exception:
  print("")
' 2>/dev/null || true
}

_tailscale_up_wait_running() {
  local pid p
  if [[ -f "$TS_UP_PIDFILE" ]]; then
    pid="$(tr -d ' \r\n' < "$TS_UP_PIDFILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  while IFS= read -r p; do
    [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null && return 0
  done < <(pgrep -f 'tailscale.* up ' 2>/dev/null || true)
  return 1
}

_refresh_authurl_file() {
  local url authfile="${SCRIPT_DIR}/CURRENT_AUTHURL.txt"
  local lastfile="${SCRIPT_DIR}/LAST_POSTED_AUTHURL.txt"
  local gh_repo="${HERMES_STATUS_GITHUB_REPO:-ilike4movies/hermes-mac-land}"
  local gh_issue="${HERMES_STATUS_GITHUB_ISSUE:-1}"
  local linear_ticket="${HERMES_AUTHURL_LINEAR_ISSUE:-RAL-823}"
  reload_cloud_secrets || true
  url="$(ts status 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[a-z0-9]+' | head -1 || true)"
  [[ -n "$url" ]] || return 0
  if [[ ! -f "$authfile" ]] || ! grep -qF "$url" "$authfile" 2>/dev/null; then
    {
      printf '%s\n' "$url"
      printf 'ACTIVE — approve now (%s).\n' "$(date -u +%FT%TZ)"
      echo 'Cloud waiters armed; TS_AUTHKEY preferred. Proactive refresh before prior TTL.'
    } >"$authfile"
    echo "APPROVE_THIS_URL=$url"
  fi
  # Best-effort auto-beacon when AuthURL changes (dedupe by URL).
  # Order: gh CLI → curl+GitHub token → Linear comment (RAL-823 by default).
  # Skips when none work — agent MCP can still post.
  if [[ "${HERMES_AUTHURL_GITHUB_BEACON:-1}" == "1" || "${HERMES_AUTHURL_LINEAR_BEACON:-1}" == "1" ]]; then
    if [[ ! -f "$lastfile" ]] || ! grep -qF "$url" "$lastfile" 2>/dev/null; then
      local body posted=0
      body="## Fresh Tailscale AuthURL (auto-beacon)

Approve NOW: ${url}

After approve, add Runtime Secrets \`HERMES_HOST_SSH_PRIVATE_KEY\` + \`LINEAR_API_KEY\` (waiters keep looping until SSH arrives).

Or Mac ONE-SHOT: \`curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command\`"
      if [[ "${HERMES_AUTHURL_GITHUB_BEACON:-1}" == "1" ]]; then
        if command -v gh >/dev/null 2>&1; then
          if gh issue comment "$gh_issue" --repo "$gh_repo" --body "$body" >/dev/null 2>&1; then
            posted=1
          fi
        fi
        if [[ "$posted" != "1" ]]; then
          local tok owner name api_url payload
          tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
          owner="${gh_repo%%/*}"
          name="${gh_repo#*/}"
          api_url="https://api.github.com/repos/${owner}/${name}/issues/${gh_issue}/comments"
          if [[ -n "$tok" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            payload="$(AUTHURL_BEACON_BODY="$body" python3 -c 'import json,os; print(json.dumps({"body": os.environ["AUTHURL_BEACON_BODY"]}))')"
            if curl -fsS -X POST \
              -H "Authorization: Bearer ${tok}" \
              -H "Accept: application/vnd.github+json" \
              -H "X-GitHub-Api-Version: 2022-11-28" \
              -H "Content-Type: application/json" \
              --data "$payload" \
              "$api_url" >/dev/null 2>&1; then
              posted=1
            fi
          fi
        fi
        if [[ "$posted" == "1" ]]; then
          echo "OK AuthURL GitHub beacon posted to ${gh_repo}#${gh_issue}"
        fi
      fi
      if [[ "$posted" != "1" && "${HERMES_AUTHURL_LINEAR_BEACON:-1}" == "1" ]]; then
        local lkey="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
        if [[ -n "$lkey" ]] && command -v python3 >/dev/null 2>&1; then
          if LINEAR_KEY="$lkey" LINEAR_TICKET="$linear_ticket" AUTHURL_BEACON_BODY="$body" python3 - <<'PY' >/dev/null 2>&1
import json, os, urllib.request
key = os.environ["LINEAR_KEY"]
ticket = os.environ["LINEAR_TICKET"]
body = os.environ["AUTHURL_BEACON_BODY"]
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
            echo "OK AuthURL Linear beacon posted to ${linear_ticket}"
          fi
        fi
      fi
      if [[ "$posted" == "1" ]]; then
        printf '%s\n' "$url" >"$lastfile"
      else
        # Throttle skip warnings (wait loop polls every ~5s).
        local warnfile="$