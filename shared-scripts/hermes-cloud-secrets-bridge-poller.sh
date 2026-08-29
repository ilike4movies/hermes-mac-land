#!/usr/bin/env bash
# Background poller: mirror Runtime Secret file mounts into /tmp/hermes-cloud-apply
# while Tailscale is still NeedsLogin so join/supervisor waiters see them immediately.
#
# Tip #141: run bridge via `bash` when the script file exists even if not +x
# (curl|raw downloads often land mode 0644). Old `-x`-only checks silently
# no-op'd for 12h+ while secrets stayed missing. Heartbeat every N polls so
# agents can prove the poller is alive from the log mtime.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
LOG="$DIR/secrets-bridge-poller.log"
PIDFILE="$DIR/secrets-bridge-poller.pid"
INTERVAL="${HERMES_SECRETS_BRIDGE_POLL_SECS:-10}"
HB_EVERY="${HERMES_SECRETS_BRIDGE_HEARTBEAT_EVERY:-30}"
mkdir -p "$DIR"
if [[ -f "$PIDFILE" ]]; then
  old="$(tr -d ' \r\n' < "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
    echo "OK secrets-bridge-poller already running pid=$old"
    exit 0
  fi
fi
echo $$ > "$PIDFILE"
echo "$(date -u +%FT%TZ) secrets-bridge-poller start interval=${INTERVAL}s tip#141 (-f bash + heartbeat/${HB_EVERY})" >>"$LOG"
_n=0
_run_bridge() {
  local cand
  for cand in \
    "$DIR/hermes-moltbot-cloud-bridge-secrets-from-env.sh" \
    "$DIR/bridge-secrets-from-env.sh" \
    "$(dirname "$0")/hermes-moltbot-cloud-bridge-secrets-from-env.sh" \
    "$(dirname "$0")/bridge-secrets-from-env.sh"
  do
    if [[ -f "$cand" ]]; then
      # Prefer tip-named bridge; chmod best-effort so interactive runs work too.
      chmod +x "$cand" 2>/dev/null || true
      bash "$cand" >>"$LOG" 2>&1 || true
      return 0
    fi
  done
  echo "$(date -u +%FT%TZ) WARN tip#141 no bridge-secrets script found under $DIR" >>"$LOG"
  return 1
}
while true; do
  _run_bridge || true
  _n=$((_n + 1))
  if (( _n % HB_EVERY == 0 )); then
    echo "$(date -u +%FT%TZ) secrets-bridge-poller heartbeat n=${_n} tip#141" >>"$LOG"
  fi
  sleep "$INTERVAL"
done
