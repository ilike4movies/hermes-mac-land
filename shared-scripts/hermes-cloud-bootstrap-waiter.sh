#!/usr/bin/env bash
# One-shot cloud bootstrap: fetch public waiter + vendor scripts, start background waiter.
# Usage: curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/PIN/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
set -euo pipefail
PIN="${HERMES_MAC_LAND_PIN:-86f8ffd454af3972079f555400d15936631751a1}"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
cd "$DIR"
_fetch() {
  local path="$1" dest="$2"
  for base in \
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}" \
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main"
  do
    if curl -fsSL "$base/$path" -o "$dest"; then
      chmod +x "$dest" 2>/dev/null || true
      echo "OK fetched $path from $base"
      return 0
    fi
  done
  return 1
}
_fetch shared-scripts/hermes-moltbot-cloud-bridge-secrets-from-env.sh bridge-secrets-from-env.sh
_fetch shared-scripts/hermes-moltbot-cloud-wait-join-then-apply.sh wait-join-then-apply.sh
_fetch shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh hermes-moltbot-cloud-apply-install-via-ssh.sh
_fetch shared-scripts/hermes-moltbot-land-beacon.sh hermes-moltbot-land-beacon.sh
if pgrep -f 'wait-join-then-apply.sh' >/dev/null 2>&1; then
  echo "OK waiter already running"
  exit 0
fi
nohup bash "$DIR/wait-join-then-apply.sh" >>"$DIR/wait-join.log" 2>&1 &
echo $! >"$DIR/waiter.pid"
echo "OK started waiter pid=$(cat "$DIR/waiter.pid") log=$DIR/wait-join.log"
echo "Inject TS_AUTHKEY / SSH keys via Cursor env secrets; waiter reloads every 15s."
