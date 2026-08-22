#!/usr/bin/env bash
# Cursor Cloud Agent start hook — bootstrap waiter + optional immediate surgical land.
# Requires Runtime Secrets at boot: TS_AUTHKEY, HERMES_HOST_SSH_PRIVATE_KEY.
# Set HERMES_AUTO_SURGICAL_LAND=0 to disable immediate land (waiter still runs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
export HERMES_CLOUD_APPLY_DIR="$DIR"

bash "$ROOT/shared-scripts/hermes-cloud-bootstrap-waiter.sh" || true

if [[ -x "$DIR/bridge-secrets-from-env.sh" ]]; then
  bash "$DIR/bridge-secrets-from-env.sh" || true
fi

if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" == "1" ]] \
  && [[ -n "${TS_AUTHKEY:-}" ]] \
  && [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
  echo "OK secrets at boot — attempting direct .11 surgical land"
  export HERMES_PREFER_DIRECT_HOST=1
  export HERMES_UPLOAD_TIP_FROM_CALLER=1
  bash "$ROOT/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh" \
    >>"$DIR/auto-land.log" 2>&1 || true
else
  echo "INFO: auto-land skipped (need TS_AUTHKEY + HERMES_HOST_SSH_PRIVATE_KEY at boot)"
fi
exit 0
