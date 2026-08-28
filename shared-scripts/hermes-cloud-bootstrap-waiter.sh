#!/usr/bin/env bash
# One-shot cloud bootstrap: fetch public waiter + vendor scripts, start background waiters.
# Usage: curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
set -euo pipefail
PIN="${HERMES_MAC_LAND_PIN:-main}"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
cd "$DIR"
_fetch() {
  local path="$1" dest="$2"
  local bases=( "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main" )
  if [[ "$PIN" != "main" ]]; then
    bases+=( "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}" )
  fi
  for base in "${bases[@]}"; do
    if curl -fsSL "$base/$path" -o "$dest"; then
      if head -1 "$dest" | grep -q '^#!/'; then
        chmod +x "$dest" 2>/dev/null || true
        echo "OK fetched $path from $base"
        return 0
      fi
      echo "WARN stub/base64 rejected for $path from $base" >&2
    fi
  done
  return 1
}
_fetch shared-scripts/hermes-moltbot-cloud-bridge-secrets-from-env.sh bridge-secrets-from-env.sh
_fetch shared-scripts/hermes-cloud-secrets-bridge-poller.sh hermes-cloud-secrets-bridge-poller.sh
_fetch shared-scripts/hermes-moltbot-cloud-wait-join-then-apply.sh wait-join-then-apply.sh
_fetch shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh hermes-moltbot-cloud-apply-install-via-ssh.sh
_fetch shared-scripts/hermes-moltbot-land-beacon.sh hermes-moltbot-land-beacon.sh
_fetch shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh hermes-moltbot-cloud-tailscale-join-and-apply.sh
_fetch shared-scripts/hermes-cloud-wait-login-supervisor.sh hermes-cloud-wait-login-supervisor.sh
_fetch shared-scripts/hermes-stage-a-preflight.sh hermes-stage-a-preflight.sh
_fetch shared-scripts/hermes-stage-a-source-preflight.sh hermes-stage-a-source-preflight.sh
_fetch shared-scripts/hermes-credentialed-resume-land.sh hermes-credentialed-resume-land.sh
if ! pgrep -f 'wait-join-then-apply.sh' >/dev/null 2>&1; then
  nohup bash "$DIR/wait-join-then-apply.sh" >>"$DIR/wait-join.log" 2>&1 &
  echo $! >"$DIR/waiter.pid"
  echo "OK started wait-join pid=$(cat "$DIR/waiter.pid") log=$DIR/wait-join.log"
else
  echo "OK wait-join already running"
fi
if ! pgrep -f 'hermes-cloud-wait-login-supervisor.sh' >/dev/null 2>&1; then
  nohup bash "$DIR/hermes-cloud-wait-login-supervisor.sh" >>"$DIR/supervisor.log" 2>&1 &
  echo $! >"$DIR/supervisor.pid"
  echo "OK started wait-login supervisor pid=$(cat "$DIR/supervisor.pid") log=$DIR/supervisor.log"
else
  echo "OK wait-login supervisor already running"
fi
if ! pgrep -f 'hermes-cloud-secrets-bridge-poller.sh' >/dev/null 2>&1; then
  if [[ -x "$DIR/hermes-cloud-secrets-bridge-poller.sh" ]]; then
    nohup bash "$DIR/hermes-cloud-secrets-bridge-poller.sh" >/dev/null 2>&1 &
    echo "OK started secrets-bridge-poller"
  fi
else
  echo "OK secrets-bridge-poller already running"
fi
echo "Inject TS_AUTHKEY / SSH keys via Cursor env secrets; waiters reload every 15s."
echo "If NeedsLogin: approve URL from $DIR/CURRENT_AUTHURL.txt or tailscale status"
echo "One-shot land+preflight: bash $DIR/hermes-credentialed-resume-land.sh"
