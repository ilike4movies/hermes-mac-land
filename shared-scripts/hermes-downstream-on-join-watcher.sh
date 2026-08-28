#!/usr/bin/env bash
# Poll until Tailscale Running AND host SSH key present, then run downstream once.
# Does not mark done while secrets are still missing (avoids one-shot race after approve).
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
  for _f in /tmp/cursor-secrets/HERMES_HOST_SSH_PRIVATE_KEY \
            "$HOME/.cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY" \
            /opt/cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY; do
    if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$_f" ]]; then
      HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$_f")"
      export HERMES_HOST_SSH_PRIVATE_KEY
    fi
  done
}

_host_ready() {
  _reload
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" || -s "$HOST_KEY_FILE" ]]
}

while true; do
  st=$(sudo tailscale --socket="$SOCK" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  print(json.load(sys.stdin).get("BackendState") or "")
except Exception:
  print("")' || true)
  if [[ "$st" == "Running" ]]; then
    if ! _host_ready; then
      echo "$(date -u +%FT%TZ) watcher: Running but host SSH missing — waiting" | tee -a "$DIR/wait-login.log"
      sleep 30
      continue
    fi
    echo "$(date -u +%FT%TZ) watcher: Running + host SSH — launching downstream" | tee -a "$DIR/wait-login.log"
    bash "$DIR/hermes-dispatcher-downstream.sh" >>"$DIR/wait-login.log" 2>&1 || true
    date -u +%FT%TZ > "$marker"
    echo "$(date -u +%FT%TZ) watcher: downstream finished" | tee -a "$DIR/wait-login.log"
    exit 0
  fi
  sleep 30
done
