#!/usr/bin/env bash
# Poll until Tailscale is Running (or jump/host already reachable), then land tip.
# Reloads secrets each loop from secrets.env / key files so mid-session inject works.
# Refreshes cloud vendor scripts from public hermes-mac-land (main preferred).
set -euo pipefail
SOCK=/var/run/tailscale/tailscaled.sock
JUMP="${HERMES_JUMP_SSH:-ilike4@100.92.147.61}"
HOST_TS="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
MAX_WAIT="${HERMES_TS_WAIT_SECS:-14400}"
SCRIPT_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
SECRETS_ENV="${HERMES_CLOUD_SECRETS_ENV:-$SCRIPT_DIR/secrets.env}"
TS_KEY_FILE="${HERMES_TS_AUTHKEY_FILE:-$SCRIPT_DIR/ts-authkey}"
JUMP_KEY_FILE="${HERMES_JUMP_SSH_KEY_FILE:-$SCRIPT_DIR/jump-ssh-key}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$SCRIPT_DIR/host-ssh-key}"
LOG="$SCRIPT_DIR/wait-join.log"
VENDOR_PIN="${HERMES_MAC_LAND_PIN:-main}"
VENDOR_REFRESH_SEC="${HERMES_VENDOR_REFRESH_SEC:-300}"
LAST_VENDOR_REFRESH=0

VENDOR_FILES=(
  shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
  shared-scripts/hermes-moltbot-land-beacon.sh
  shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh
  shared-scripts/hermes-cloud-wait-login-supervisor.sh
  shared-scripts/hermes-moltbot-cloud-bridge-secrets-from-env.sh
)

_is_valid_script() {
  local f="$1"
  [[ -s "$f" ]] || return 1
  head -1 "$f" | grep -q '^#!/' || return 1
  grep -q '^PLACEHOLDER$' "$f" 2>/dev/null && return 1
  # reject accidental base64-stub pushes (literal IyEvdXNy... not shebang)
  head -1 "$f" | grep -q '^IyE' && return 1
  return 0
}

_refresh_public_vendor() {
  local now pin="$VENDOR_PIN" base f bn dest
  now=$(date +%s)
  if (( now - LAST_VENDOR_REFRESH < VENDOR_REFRESH_SEC )); then
    return 0
  fi
  LAST_VENDOR_REFRESH=$now
  mkdir -p "$SCRIPT_DIR/shared-scripts"
  local bases=( "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main" )
  if [[ "$pin" != "main" ]]; then
    bases+=( "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${pin}" )
  fi
  for base in "${bases[@]}"; do
    local ok=1 tmpdir
    tmpdir="$(mktemp -d)"
    for f in "${VENDOR_FILES[@]}"; do
      bn="$(basename "$f")"
      dest="$tmpdir/$bn"
      if ! curl -fsSL "$base/$f" -o "$dest"; then
        ok=0
        break
      fi
      if ! _is_valid_script "$dest"; then
        ok=0
        break
      fi
    done
    if [[ "$ok" -eq 1 ]]; then
      for f in "${VENDOR_FILES[@]}"; do
        bn="$(basename "$f")"
        install -m 0755 "$tmpdir/$bn" "$SCRIPT_DIR/$bn"
      done
      # legacy dest names used by bootstrap
      install -m 0755 "$tmpdir/hermes-moltbot-cloud-bridge-secrets-from-env.sh" "$SCRIPT_DIR/bridge-secrets-from-env.sh" 2>/dev/null || true
      rm -rf "$tmpdir"
      echo "$(date -u +%H:%M:%S) OK refreshed vendor (${#VENDOR_FILES[@]} scripts) from $base"
      return 0
    fi
    rm -rf "$tmpdir"
  done
  echo "$(date -u +%H:%M:%S) WARN vendor refresh failed (using existing scripts)"
  return 0
}

reload_secrets() {
  if [[ -x "$SCRIPT_DIR/bridge-secrets-from-env.sh" ]]; then
    # shellcheck disable=SC1091
    bash "$SCRIPT_DIR/bridge-secrets-from-env.sh" >/dev/null 2>&1 || true
  elif [[ -x "$SCRIPT_DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" ]]; then
    bash "$SCRIPT_DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" >/dev/null 2>&1 || true
  fi
  if [[ -f "$SECRETS_ENV" ]]; then
    set -a; # shellcheck disable=SC1090
    source "$SECRETS_ENV"; set +a
  fi
  if [[ -z "${TS_AUTHKEY:-}" && -f "$TS_KEY_FILE" ]]; then
    TS_AUTHKEY="$(tr -d '\r\n' < "$TS_KEY_FILE")"
    export TS_AUTHKEY
  fi
  for _f in "$SCRIPT_DIR/ts-authkey" /tmp/cursor-secrets/TS_AUTHKEY "$HOME/.cursor/secrets/TS_AUTHKEY"; do
    if [[ -z "${TS_AUTHKEY:-}" && -f "$_f" ]]; then
      TS_AUTHKEY="$(tr -d '\r\n' < "$_f")"
      export TS_AUTHKEY
    fi
  done
  if [[ -z "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" && -f "$JUMP_KEY_FILE" ]]; then
    HERMES_JUMP_SSH_PRIVATE_KEY="$(cat "$JUMP_KEY_FILE")"
    export HERMES_JUMP_SSH_PRIVATE_KEY
  fi
  for _f in /tmp/cursor-secrets/HERMES_JUMP_SSH_PRIVATE_KEY "$HOME/.cursor/secrets/HERMES_JUMP_SSH_PRIVATE_KEY"; do
    if [[ -z "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" && -f "$_f" ]]; then
      HERMES_JUMP_SSH_PRIVATE_KEY="$(cat "$_f")"
      export HERMES_JUMP_SSH_PRIVATE_KEY
    fi
  done
  if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$HOST_KEY_FILE" ]]; then
    HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$HOST_KEY_FILE")"
    export HERMES_HOST_SSH_PRIVATE_KEY
  fi
  for _f in /tmp/cursor-secrets/HERMES_HOST_SSH_PRIVATE_KEY "$HOME/.cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY"; do
    if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$_f" ]]; then
      HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$_f")"
      export HERMES_HOST_SSH_PRIVATE_KEY
    fi
  done
}

_reachable() {
  local host="$1"
  ping -c 1 -W 2 "$host" >/dev/null 2>&1 && return 0
  timeout 2 bash -c "echo >/dev/tcp/$host/22" 2>/dev/null && return 0
  return 1
}

_ensure_supervisor() {
  if pgrep -f 'hermes-cloud-wait-login-supervisor.sh' >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x "$SCRIPT_DIR/hermes-cloud-wait-login-supervisor.sh" ]]; then
    nohup bash "$SCRIPT_DIR/hermes-cloud-wait-login-supervisor.sh" >>"$SCRIPT_DIR/supervisor.log" 2>&1 &
    echo "$(date -u +%H:%M:%S) OK started wait-login supervisor pid=$!"
  fi
}

mkdir -p "$SCRIPT_DIR"
_refresh_public_vendor || true
exec >>"$LOG" 2>&1
echo "== wait-join-then-apply max=${MAX_WAIT}s jump=$JUMP host_ts=$HOST_TS host_lan=$HOST_LAN pin=$VENDOR_PIN started=$(date -u +%FT%TZ) =="
start=$(date +%s)
while true; do
  _refresh_public_vendor || true
  _ensure_supervisor || true
  reload_secrets
  st=$(sudo tailscale --socket="$SOCK" status --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("BackendState") or d.get("Self",{}).get("Online"))' 2>/dev/null || echo unknown)
  echo "$(date -u +%H:%M:%S) BackendState/online=$st authkey=${TS_AUTHKEY:+set} jumpkey=${HERMES_JUMP_SSH_PRIVATE_KEY:+set} hostkey=${HERMES_HOST_SSH_PRIVATE_KEY:+set}"

  mesh_ok=0
  if echo "$st" | grep -qiE 'Running|True|true'; then
    mesh_ok=1
  fi

  if [[ "$mesh_ok" -eq 1 ]]; then
    if _reachable 100.92.147.61 || _reachable 100.105.194.96 || _reachable 192.168.1.11; then
      echo "OK mesh/host reachable — running tip via-ssh (jump then direct .11)"
      break
    fi
    echo "joined but jump/host not reachable yet"
  elif _reachable 100.92.147.61 || _reachable 100.105.194.96 || _reachable 192.168.1.11; then
    echo "OK target reachable without BackendState=Running — attempting land"
    break
  fi

  if [[ -n "${TS_AUTHKEY:-}" ]]; then
    echo "TS_AUTHKEY present — joining with authkey"
    sudo tailscale --socket="$SOCK" up --authkey="$TS_AUTHKEY" --hostname=cursor-cloud-hermes --accept-routes=true || true
  fi
  now=$(date +%s)
  if (( now - start > MAX_WAIT )); then
    echo "ERROR: timeout waiting for Tailscale join / host reachability" >&2
    exit 1
  fi
  sleep 15
done

VIA="$SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"
if [[ ! -f "$VIA" ]]; then
  echo "ERROR: missing $VIA" >&2
  exit 1
fi
bash "$VIA"
echo "OK apply attempted rc=$?"