#!/usr/bin/env bash
# Keep wait-login alive until Tailscale Running, then auto-land / downstream.
# When HERMES_AUTO_SURGICAL_LAND=0: wait for host SSH key (mid-wait secrets) before
# running dispatcher downstream — do not one-shot-and-exit on Running alone.
# Tip #137/#138: spawn inherits tip#131 forever up default + tip#136 DESIRED_UP_TIMEOUT
# persist. Prefer hermes-cloud-attach-wait-login.sh over restart-authurl when AuthURL live.
# Tip #138: _spawn_wait_login uses $DIR/wait-login.flock (shared with attach) + re-check
# so attach↔supervisor cannot both spawn wait-login and remint AuthURL.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$DIR/host-ssh-key}"
SECRETS_ENV="${HERMES_CLOUD_SECRETS_ENV:-$DIR/secrets.env}"
cd "$DIR"

backend_state() {
  sudo tailscale --socket="$SOCK" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get("BackendState") or "")
except Exception:
  print("")' 2>/dev/null || true
}

_tailscale_up_wait_running() {
  local pid
  if [[ -f "$DIR/tailscale-up-wait.pid" ]]; then
    pid="$(tr -d ' \r\n' < "$DIR/tailscale-up-wait.pid" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && return 0
  fi
  pgrep -f 'tailscale.* up ' >/dev/null 2>&1
}

_wait_login_active() {
  local pid cmdline
  if [[ -f "$DIR/waiter.pid" ]]; then
    pid="$(tr -d ' \r\n' < "$DIR/waiter.pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
      if [[ "$cmdline" == *'hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login'* ]]; then
        return 0
      fi
    fi
  fi
  # Fallback: any live wait-login (exclude our own cmdline via exact script name).
  pgrep -f 'hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login' >/dev/null 2>&1
}

_spawn_wait_login() {
  # Tip #138 shared flock + re-check: attach and supervisor cannot both spawn.
  (
    flock -n 200 || {
      echo "$(date -u +%FT%TZ) wait-login spawn skipped (flock held)"
      exit 0
    }
    if _wait_login_active; then
      echo "$(date -u +%FT%TZ) wait-login already active — not spawning"
      exit 0
    fi
    if _tailscale_up_wait_running; then
      echo "$(date -u +%FT%TZ) tailscale up wait running — attaching wait-login (BackendState=${st:-unknown})"
    else
      echo "$(date -u +%FT%TZ) starting wait-login (BackendState=${st:-unknown})"
    fi
    # Tip #124: wait-login respawns inherit soft AuthURL keep-alive by default
    # (tip #123). Do not force hard wipe on supervisor restart mid-approve.
    # Tip #137: default forever up timeout + tip#136 DESIRED_UP_TIMEOUT persist so
    # supervisor respawns do not cold-start forever=0 mid finite hold-roll.
    export HERMES_AUTHURL_HARD_ON_REFRESH="${HERMES_AUTHURL_HARD_ON_REFRESH:-0}"
    export HERMES_TAILSCALE_UP_TIMEOUT_SECS="${HERMES_TAILSCALE_UP_TIMEOUT_SECS:-0}"
    if [[ -f "$DIR/DESIRED_UP_TIMEOUT.txt" ]]; then
      _desired="$(tr -d ' \r\n' <"$DIR/DESIRED_UP_TIMEOUT.txt" 2>/dev/null || true)"
      if [[ "${_desired}" =~ ^[0-9]+$ ]] && (( _desired > 0 )); then
        export HERMES_TAILSCALE_UP_TIMEOUT_SECS="$_desired"
        echo "$(date -u +%FT%TZ) tip#137 adopt DESIRED_UP_TIMEOUT=${_desired}s for wait-login spawn"
      fi
    fi
    echo "$(date -u +%FT%TZ) wait-login spawn HARD=${HERMES_AUTHURL_HARD_ON_REFRESH} UP_TIMEOUT=${HERMES_TAILSCALE_UP_TIMEOUT_SECS}s"
    bash "$DIR/hermes-moltbot-cloud-tailscale-join-and-apply.sh" --wait-login >>"$DIR/wait-login.log" 2>&1 &
    echo $! >"$DIR/waiter.pid"
  ) 200>"$DIR/wait-login.flock"
}

_reload_host_secrets() {
  if [[ -f "$SECRETS_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$SECRETS_ENV"; set +a
  fi
  if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -s "$HOST_KEY_FILE" ]]; then
    HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$HOST_KEY_FILE")"
    export HERMES_HOST_SSH_PRIVATE_KEY
  fi
  for _f in /tmp/cursor/cloud-agent-secrets/HERMES_HOST_SSH_PRIVATE_KEY \
            /tmp/cursor-secrets/HERMES_HOST_SSH_PRIVATE_KEY \
            "$HOME/.cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY" \
            /opt/cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY; do
    if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$_f" ]]; then
      HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$_f")"
      export HERMES_HOST_SSH_PRIVATE_KEY
    fi
  done
  if [[ -z "${LINEAR_API_KEY:-}" && -s "$DIR/linear-api-key" ]]; then
    LINEAR_API_KEY="$(tr -d '\r\n' < "$DIR/linear-api-key")"
    export LINEAR_API_KEY
  fi
  if [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && ! -s "$HOST_KEY_FILE" ]]; then
    printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY" > "$HOST_KEY_FILE"
    chmod 600 "$HOST_KEY_FILE" 2>/dev/null || true
  fi
}

_host_ssh_ready() {
  _reload_host_secrets
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && return 0
  [[ -s "$HOST_KEY_FILE" ]] && return 0
  return 1
}

_run_bridge() {
  # Tip #144: -f + bash (0644 curl downloads), not -x-only.
  local cand
  for cand in     "$DIR/bridge-secrets-from-env.sh"     "$DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh"
  do
    if [[ -f "$cand" ]]; then
      chmod +x "$cand" 2>/dev/null || true
      bash "$cand" >/dev/null 2>&1 || true
      return 0
    fi
  done
}

_ensure_secrets_bridge_poller() {
  if pgrep -f 'hermes-cloud-secrets-bridge-poller.sh' >/dev/null 2>&1; then
    return 0
  fi
  # Tip #144: resolve poller via -f (+ CDN), not -x-only (tip#141 class).
  local poller="" cand
  for cand in     "$DIR/hermes-cloud-secrets-bridge-poller.sh"     "$(dirname "$0")/hermes-cloud-secrets-bridge-poller.sh"     "$(dirname "$0")/shared-scripts/hermes-cloud-secrets-bridge-poller.sh"
  do
    if [[ -f "$cand" ]]; then
      chmod +x "$cand" 2>/dev/null || true
      poller="$cand"
      break
    fi
  done
  if [[ -z "$poller" ]]; then
    poller="$DIR/hermes-cloud-secrets-bridge-poller.sh"
    echo "$(date -u +%FT%TZ) tip#144 fetching hermes-cloud-secrets-bridge-poller.sh"
    curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-secrets-bridge-poller.sh" -o "$poller" || true
    chmod +x "$poller" 2>/dev/null || true
  fi
  if [[ -f "$poller" ]]; then
    nohup bash "$poller" >/dev/null 2>&1 &
    echo "$(date -u +%FT%TZ) started secrets-bridge-poller (tip#144)"
  else
    echo "$(date -u +%FT%TZ) WARN: secrets-bridge-poller missing (tip#144)"
  fi
}

while true; do
  _run_bridge
  _ensure_secrets_bridge_poller
  st="$(backend_state)"
  if [[ "$st" == "Running" ]]; then
    echo "$(date -u +%FT%TZ) OK Running — Tailscale joined"
    if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" != "1" ]]; then
      if ! _host_ssh_ready; then
        echo "$(date -u +%FT%TZ) Running but HERMES_HOST_SSH_PRIVATE_KEY missing — waiting for Runtime Secrets / $HOST_KEY_FILE (not exiting)"
        sleep 30
        continue
      fi
      echo "$(date -u +%FT%TZ) land disabled — host SSH ready; tip#143/#133 single-flight downstream"
      # Tip #143: resolve once launcher via -f (+ CDN), not -x-only.
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
        echo "$(date -u +%FT%TZ) tip#143 fetching hermes-cloud-run-downstream-once.sh"
        curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-run-downstream-once.sh" -o "$once" || true
        chmod +x "$once" 2>/dev/null || true
      fi
      if [[ -f "$once" ]]; then
        export HERMES_CLOUD_APPLY_DIR="$DIR"
        if bash "$once"; then
          echo "$(date -u +%FT%TZ) tip#133 downstream SUCCESS — supervisor exiting"
          exit 0
        fi
        echo "$(date -u +%FT%TZ) tip#133 downstream FAIL — will retry (not exiting)"
        sleep 60
        continue
      else
        echo "$(date -u +%FT%TZ) WARN: hermes-cloud-run-downstream-once.sh missing (tip#143)"
        sleep 60
        continue
      fi
    fi
    echo "$(date -u +%FT%TZ) OK Running — landing tip"
    bash "$DIR/hermes-moltbot-cloud-tailscale-join-and-apply.sh" --already-up >>"$DIR/wait-login.log" 2>&1 || true
    echo "$(date -u +%FT%TZ) land attempt finished rc=$?"
    exit 0
  fi
  if ! _wait_login_active; then
    _spawn_wait_login
  fi
  sleep 60
done
