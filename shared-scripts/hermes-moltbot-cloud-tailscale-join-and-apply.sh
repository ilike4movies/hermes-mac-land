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
  # Prefer bridge so cursor-secrets mounts + env land in key files first
  if [[ -x "$SCRIPT_DIR/bridge-secrets-from-env.sh" ]]; then
    bash "$SCRIPT_DIR/bridge-secrets-from-env.sh" >/dev/null 2>&1 || true
  elif [[ -x "$SCRIPT_DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" ]]; then
    bash "$SCRIPT_DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" >/dev/null 2>&1 || true
  fi
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
  for _f in /tmp/cursor-secrets/HERMES_HOST_SSH_PRIVATE_KEY             "$HOME/.cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY"             /opt/cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY; do
    if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$_f" ]]; then
      HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$_f")"
      export HERMES_HOST_SSH_PRIVATE_KEY
      printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY" > "$HOST_KEY_FILE"
      chmod 600 "$HOST_KEY_FILE" 2>/dev/null || true
    fi
  done
  if [[ -z "${LINEAR_API_KEY:-}" && -f "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}" ]]; then
    LINEAR_API_KEY="$(tr -d '\r\n' < "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}")"
    export LINEAR_API_KEY
  fi
  for _f in /tmp/cursor-secrets/LINEAR_API_KEY             "$HOME/.cursor/secrets/LINEAR_API_KEY"             /opt/cursor/secrets/LINEAR_API_KEY; do
    if [[ -z "${LINEAR_API_KEY:-}" && -f "$_f" ]]; then
      LINEAR_API_KEY="$(tr -d '\r\n' < "$_f")"
      export LINEAR_API_KEY
      printf '%s' "$LINEAR_API_KEY" > "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}"
      chmod 600 "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}" 2>/dev/null || true
    fi
  done
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
      lo