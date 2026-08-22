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
  url="$(ts status 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[a-z0-9]+' | head -1 || true)"
  [[ -n "$url" ]] || return 0
  if [[ ! -f "$authfile" ]] || ! grep -qF "$url" "$authfile" 2>/dev/null; then
    {
      printf '%s\n' "$url"
      printf 'ACTIVE — approve now (%s).\n' "$(date -u +%FT%TZ)"
      echo 'Cloud waiters armed; TS_AUTHKEY preferred.'
    } >"$authfile"
    echo "APPROVE_THIS_URL=$url"
  fi
}

_ensure_single_tailscale_up_wait() {
  local login_wait_secs="${1:-$LOGIN_WAIT_SECS}"
  if _tailscale_up_wait_running; then
    echo "OK tailscale up wait already running (pidfile=$(cat "$TS_UP_PIDFILE" 2>/dev/null || echo none))"
    _refresh_authurl_file
    return 0
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

wait_for_jump

export HERMES_JUMP_SSH="$JUMP_SSH"
bash "$SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"

echo "OK cloud-tailscale-join-and-apply finished (expect OK INTERRUPT_LABEL hermes-now)"
exit 0
