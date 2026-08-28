#!/usr/bin/env bash
# Background poller: mirror Runtime Secret file mounts into /tmp/hermes-cloud-apply
# while Tailscale is still NeedsLogin so join/supervisor waiters see them immediately.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
LOG="$DIR/secrets-bridge-poller.log"
PIDFILE="$DIR/secrets-bridge-poller.pid"
INTERVAL="${HERMES_SECRETS_BRIDGE_POLL_SECS:-30}"
mkdir -p "$DIR"
if [[ -f "$PIDFILE" ]]; then
  old="$(tr -d ' \r\n' < "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
    echo "OK secrets-bridge-poller already running pid=$old"
    exit 0
  fi
fi
echo $$ > "$PIDFILE"
echo "$(date -u +%FT%TZ) secrets-bridge-poller start interval=${INTERVAL}s" >>"$LOG"
while true; do
  if [[ -x "$DIR/bridge-secrets-from-env.sh" ]]; then
    bash "$DIR/bridge-secrets-from-env.sh" >>"$LOG" 2>&1 || true
  elif [[ -x "$DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" ]]; then
    bash "$DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" >>"$LOG" 2>&1 || true
  elif [[ -x "$(dirname "$0")/hermes-moltbot-cloud-bridge-secrets-from-env.sh" ]]; then
    bash "$(dirname "$0")/hermes-moltbot-cloud-bridge-secrets-from-env.sh" >>"$LOG" 2>&1 || true
  fi
  sleep "$INTERVAL"
done
