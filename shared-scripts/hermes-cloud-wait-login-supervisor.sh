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

while true; do
  st="$(backend_state)"
  if [[ "$st" == "Running" ]]; then
    echo "$(date -u +%FT%TZ) OK Running — landing tip"
    bash "$DIR/hermes-moltbot-cloud-tailscale-join-and-apply.sh" --already-up >>"$DIR/wait-login.log" 2>&1 || true
    echo "$(date -u +%FT%TZ) land attempt finished rc=$?"
    exit 0
  fi
  if ! pgrep -f 'hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login' >/dev/null 2>&1; then
    echo "$(date -u +%FT%TZ) starting wait-login (BackendState=${st:-unknown})"
    bash "$DIR/hermes-moltbot-cloud-tailscale-join-and-apply.sh" --wait-login >>"$DIR/wait-login.log" 2>&1 &
  fi
  sleep 60
done
