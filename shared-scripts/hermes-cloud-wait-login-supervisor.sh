#!/usr/bin/env bash
# Keep wait-login alive until Tailscale Running, then auto-land.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
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
  pgrep -f 'hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login' >/dev/null 2>&1
}

while true; do
  st="$(backend_state)"
  if [[ "$st" == "Running" ]]; then
    echo "$(date -u +%FT%TZ) OK Running — landing tip"
    bash "$DIR/hermes-moltbot-cloud-tailscale-join-and-apply.sh" --already-up >>"$DIR/wait-login.log" 2>&1 || true
    echo "$(date -u +%FT%TZ) land attempt finished rc=$?"
    exit 0
  fi
  if ! _wait_login_active; then
    if _tailscale_up_wait_running; then
      echo "$(date -u +%FT%TZ) tailscale up wait running — attaching wait-login (BackendState=${st:-unknown})"
    else
      echo "$(date -u +%FT%TZ) starting wait-login (BackendState=${st:-unknown})"
    fi
    bash "$DIR/hermes-moltbot-cloud-tailscale-join-and-apply.sh" --wait-login >>"$DIR/wait-login.log" 2>&1 &
  fi
  sleep 60
done
