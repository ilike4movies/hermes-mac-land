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
    # Local marker for cloud agents (MCP) when gh tip write is unavailable.
    {
      printf '%s\n' "$url"
      printf 'refreshed=%s\n' "$(date -u +%FT%TZ)"
    } >"${SCRIPT_DIR}/PENDING_AUTHURL_TIP.txt"
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
        # Keep tip CURRENT_AUTHURL.md in sync so Mac ONE-SHOT (#92) opens the live URL.
        if [[ "${HERMES_AUTHURL_TIP_FILE:-1}" == "1" ]]; then
          local tip_path="CURRENT_AUTHURL.md" tip_body tip_sha tip_b64 tip_tok tip_owner tip_name tip_api tip_payload tip_put
          tip_body="# Live cloud Tailscale AuthURL

**Last refreshed:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Approve:** ${url}

Do **not** use older AuthURLs. Prefer Mac ONE-SHOT if Runtime Secrets stay unset.

After approve, cloud still needs \`HERMES_HOST_SSH_PRIVATE_KEY\` (+ preferably \`LINEAR_API_KEY\` / \`TS_AUTHKEY\`) unless Mac ONE-SHOT completes Downstream DONE.

Hostname to approve: \`cursor-cloud-hermes\`

Admin: https://login.tailscale.com/admin/machines
"
          tip_tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
          tip_owner="${gh_repo%%/*}"
          tip_name="${gh_repo#*/}"
          tip_sha=""
          if command -v gh >/dev/null 2>&1; then
            tip_sha="$(gh api "repos/${gh_repo}/contents/${tip_path}" --jq .sha 2>/dev/null || true)"
          elif [[ -n "$tip_tok" ]] && command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
            tip_sha="$(curl -fsS -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"               "https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${tip_path}" 2>/dev/null               | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sha",""))' 2>/dev/null || true)"
          fi
          tip_b64="$(printf '%s' "$tip_body" | base64 | tr -d '\n')"
          if command -v gh >/dev/null 2>&1; then
            if [[ -n "$tip_sha" ]]; then
              tip_put=(gh api --method PUT "repos/${gh_repo}/contents/${tip_path}" -f message="ops: refresh CURRENT_AUTHURL.md" -f content="$tip_b64" -f branch=main -f sha="$tip_sha")
            else
              tip_put=(gh api --method PUT "repos/${gh_repo}/contents/${tip_path}" -f message="ops: refresh CURRENT_AUTHURL.md" -f content="$tip_b64" -f branch=main)
            fi
            if "${tip_put[@]}" >/dev/null 2>&1; then
              echo "OK tip CURRENT_AUTHURL.md refreshed on ${gh_repo}"
              posted=1
            fi
          elif [[ -n "$tip_tok" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            tip_api="https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${tip_path}"
            tip_payload="$(TIP_B64="$tip_b64" TIP_SHA="$tip_sha" python3 -c 'import json,os; d={"message":"ops: refresh CURRENT_AUTHURL.md","content":os.environ["TIP_B64"],"branch":"main"}; s=os.environ.get("TIP_SHA") or "";
print(json.dumps({**d, **({"sha":s} if s else {})}))')"
            if curl -fsS -X PUT -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"               -H "Content-Type: application/json" --data "$tip_payload" "$tip_api" >/dev/null 2>&1; then
              echo "OK tip CURRENT_AUTHURL.md refreshed on ${gh_repo} (curl)"
              posted=1
            fi
          fi
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
        local warnfile="${SCRIPT_DIR}/LAST_AUTHURL_BEACON_WARN.txt"
        local now warn_age=99999
        now="$(date +%s)"
        if [[ -f "$warnfile" ]]; then
          warn_age=$(( now - $(stat -c %Y "$warnfile" 2>/dev/null || echo 0) ))
        fi
        if (( warn_age >= ${HERMES_AUTHURL_BEACON_WARN_SECS:-60} )); then
          echo "WARN AuthURL beacon skipped (gh/token/Linear write unavailable)"
          printf '%s\n' "$url" >"$warnfile"
        fi
      fi
    fi
  fi
}

_ensure_single_tailscale_up_wait() {
  local login_wait_secs="${1:-$LOGIN_WAIT_SECS}"
  # Proactive AuthURL refresh: if interactive up has been waiting ~45m+ and still
  # NeedsLogin, kill and restart so operators get a fresh approve URL (TTL~1h).
  # Prefer ~45m over ~15m: frequent kills invalidate open approve links mid-click.
  if _tailscale_up_wait_running; then
    local age_s=0 pid
    if [[ -f "$TS_UP_PIDFILE" ]]; then
      pid="$(tr -d ' \r\n' < "$TS_UP_PIDFILE" 2>/dev/null || true)"
    fi
    # Adopt orphan up process into pidfile when missing (post-kill race).
    if [[ -z "${pid:-}" ]] || ! kill -0 "${pid:-}" 2>/dev/null; then
      pid="$(pgrep -f 'tailscale.* up --timeout' 2>/dev/null | head -1 || true)"
      if [[ -n "$pid" ]]; then
        echo "$pid" >"$TS_UP_PIDFILE"
      fi
    fi
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      age_s="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)"
    fi
    if [[ "${age_s:-0}" =~ ^[0-9]+$ ]] && (( age_s >= ${HERMES_TAILSCALE_AUTHURL_REFRESH_SECS:-2700} )); then
      echo "WARN proactive AuthURL refresh — up wait age=${age_s}s >= refresh threshold; restarting"
      if [[ -n "${pid:-}" ]]; then
        sudo kill "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        # also kill child tailscale up if sudo wrapper
        pkill -f "tailscale.* up --timeout" 2>/dev/null || true
        sleep 2
      fi
      rm -f "$TS_UP_PIDFILE" 2>/dev/null || true
    else
      echo "OK tailscale up wait already running (pidfile=$(cat "$TS_UP_PIDFILE" 2>/dev/null || echo none) age_s=${age_s:-?})"
      _refresh_authurl_file
      return 0
    fi
  fi
  exec 9>"$TS_UP_LOCK"
  if ! flock -n 9; then
    echo "OK another process holds tailscale-up lock"
    _refresh_authurl_file
    return 0
  fi
  if _tailscale_up_wait_running; then
    _refresh_authurl_file
    return 0
  fi
  echo "== starting single tailscale up wait (${login_wait_secs}s) =="
  nohup sudo tailscale --socket="$SOCK" up --timeout="${login_wait_secs}s" \
    --hostname="${HERMES_TS_HOSTNAME:-cursor-cloud-hermes}" --accept-routes=true \
    >/tmp/tailscale-up-wait.log 2>&1 &
  echo $! >"$TS_UP_PIDFILE"
  echo "OK started tailscale up wait pid=$(cat "$TS_UP_PIDFILE")"
  sleep 2
  _refresh_authurl_file
}

install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    echo "OK tailscale already installed: $(command -v tailscale)"
    return 0
  fi
  echo "== installing Tailscale =="
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: auto-install only implemented for Linux cloud agents" >&2
    exit 1
  fi
  curl -fsSL https://tailscale.com/install.sh | sh
  command -v tailscale >/dev/null 2>&1
}

ensure_daemon() {
  if pgrep -x tailscaled >/dev/null 2>&1; then
    return 0
  fi
  sudo mkdir -p /var/run/tailscale /var/lib/tailscale /var/cache/tailscale
  if [[ -e /dev/net/tun ]]; then
    sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket="$SOCK" --port=41641 >/tmp/tailscaled.log 2>&1 &
  else
    echo "WARN: /dev/net/tun missing — userspace networking"
    sudo tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket="$SOCK" >/tmp/tailscaled-userspace.log 2>&1 &
  fi
  sleep 2
}

join_tailscale_authkey() {
  echo "== joining Tailscale mesh with TS_AUTHKEY =="
  ts up --authkey="$TS_AUTHKEY" --hostname="${HERMES_TS_HOSTNAME:-cursor-cloud-hermes}" --accept-routes=true
  ts status || true
}

wait_for_running() {
  local max="$1" i=0 st
  echo "== waiting up to ${max}s for BackendState=Running =="
  while (( i < max )); do
    reload_cloud_secrets
    st="$(backend_state)"
    echo "  t=${i}s BackendState=${st:-unknown} authkey=${TS_AUTHKEY:+set}"
    if [[ "$st" == "Running" ]]; then
      return 0
    fi
    if [[ -n "${TS_AUTHKEY:-}" && "$st" != "Running" ]]; then
      echo "  mid-wait TS_AUTHKEY present — joining"
      join_tailscale_authkey || true
    fi
    if [[ "$st" == "NeedsLogin" || "$st" == "NoState" || -z "$st" ]]; then
      _ensure_single_tailscale_up_wait "$max" || true
      _refresh_authurl_file || true
      ts status 2>&1 | sed -n '1,8p' || true
    fi
    sleep 5
    i=$((i + 5))
  done
  echo "ERROR: Tailscale not Running after ${max}s" >&2
  return 1
}

wait_for_jump() {
  local i
  echo "== waiting up to ${WAIT_SECS}s for jump $JUMP_HOST =="
  for ((i=0; i<WAIT_SECS; i+=3)); do
    if ping -c 1 -W 2 "$JUMP_HOST" >/dev/null 2>&1; then
      echo "OK ping $JUMP_HOST after ${i}s"
      return 0
    fi
    if timeout 2 bash -c "echo >/dev/tcp/${JUMP_HOST}/22" 2>/dev/null; then
      echo "OK tcp/22 $JUMP_HOST after ${i}s"
      return 0
    fi
    sleep 3
  done
  echo "ERROR: jump $JUMP_HOST not reachable after ${WAIT_SECS}s" >&2
  return 1
}

reload_cloud_secrets
install_tailscale
ensure_daemon

st_now="$(backend_state)"
if [[ "$ALREADY_UP" -eq 1 || "$st_now" == "Running" ]]; then
  echo "OK Tailscale already Running (or --already-up); skipping join"
elif [[ -n "${TS_AUTHKEY:-}" ]]; then
  join_tailscale_authkey
  wait_for_running "$WAIT_SECS" || true
elif [[ "$WAIT_LOGIN" -eq 1 ]]; then
  echo "== interactive login path (approve AuthURL; single tailscale up) =="
  _ensure_single_tailscale_up_wait "$LOGIN_WAIT_SECS"
  ts status 2>&1 | sed -n '1,12p' || true
  wait_for_running "$LOGIN_WAIT_SECS"
else
  echo "ERROR: TS_AUTHKEY unset and not Running. Re-run with TS_AUTHKEY=... or --wait-login / --already-up" >&2
  exit 2
fi

# Downstream-only prefers direct host SSH; do not abort the closed-loop path
# if jump ping fails after Tailscale Running (routes may still reach .11).
if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" != "1" ]]; then
  if ! wait_for_jump; then
    echo "WARN jump not reachable — continuing downstream-only (direct host SSH)"
  fi
else
  wait_for_jump
fi

# When surgical land is disabled (stalled-canary recovery), run dispatcher
# downstream instead of via-ssh tip land. Still needs host SSH + Linear keys.
if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" != "1" ]]; then
  echo "== HERMES_AUTO_SURGICAL_LAND=0 — dispatcher downstream (not surgical land) =="
  wait_for_host_ssh_key || {
    echo "ERROR: cannot run downstream without HERMES_HOST_SSH_PRIVATE_KEY" >&2
    exit 1
  }
  ds="$SCRIPT_DIR/hermes-dispatcher-downstream.sh"
  if [[ ! -x "$ds" ]]; then
    echo "ERROR: missing $ds" >&2
    exit 1
  fi
  export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
  export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
  export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
  export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
  export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
  bash "$ds"
  echo "OK cloud-tailscale-join-and-apply finished (downstream-only)"
  exit 0
fi

export HERMES_JUMP_SSH="$JUMP_SSH"
bash "$SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"

echo "OK cloud-tailscale-join-and-apply finished (expect OK INTERRUPT_LABEL hermes-now)"
exit 0
