#!/usr/bin/env bash
# Tip #133: single-flight credentialed downstream launcher.
# Shared by wait-login (join-part-c), wait-login-supervisor, and on-join watcher so
# Running+SSH does not triple-run stall recovery. Marker written only on success
# so a transient FAIL can retry (prior on-join wrote done even after || true).
#
# Tip #142: resolve dispatcher via `bash` when the file exists even if not +x
# (same class as tip #141 secrets-bridge). If missing locally, fetch tip CDN
# `shared-scripts/hermes-dispatcher-downstream.sh` before failing closed —
# post-approve on-join must not exit 127 with AuthURL already approved.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
LOCK="${HERMES_DOWNSTREAM_LAUNCH_LOCK:-$DIR/downstream-launch.lock}"
MARKER="${HERMES_DOWNSTREAM_DONE_MARKER:-$DIR/downstream-on-join.done}"
LOG="${HERMES_DOWNSTREAM_LAUNCH_LOG:-$DIR/wait-login.log}"
DS="${HERMES_DISPATCHER_DOWNSTREAM_SH:-$DIR/hermes-dispatcher-downstream.sh}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"

export HERMES_AUTO_SURGICAL_LAND="${HERMES_AUTO_SURGICAL_LAND:-0}"
export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
export COMPOSER_REPO_URL="${HERMES_DOWNSTREAM_COMPOSER_REPO_URL:-github.com/ilike4movies/hermes-mac-land}"

mkdir -p "$DIR"
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "$(date -u +%FT%TZ) OK tip#133 downstream launch skipped (flock held)" | tee -a "$LOG"
  exit 0
fi

if [[ -f "$MARKER" && "${HERMES_DOWNSTREAM_FORCE:-0}" != "1" ]]; then
  echo "$(date -u +%FT%TZ) OK tip#133 downstream already done (marker=$MARKER)" | tee -a "$LOG"
  exit 0
fi

_resolve_ds() {
  local cand alt
  for cand in \
    "$DS" \
    "$DIR/hermes-dispatcher-downstream.sh" \
    "$(cd "$(dirname "$0")" && pwd)/hermes-dispatcher-downstream.sh" \
    "$(cd "$(dirname "$0")" && pwd)/shared-scripts/hermes-dispatcher-downstream.sh"
  do
    if [[ -f "$cand" ]]; then
      chmod +x "$cand" 2>/dev/null || true
      DS="$cand"
      return 0
    fi
  done
  alt="$DIR/hermes-dispatcher-downstream.sh"
  echo "$(date -u +%FT%TZ) tip#142 fetching hermes-dispatcher-downstream.sh from ${REPO}@${PIN}" | tee -a "$LOG"
  if curl -fsSL "https://raw.githubusercontent.com/${REPO}/${PIN}/shared-scripts/hermes-dispatcher-downstream.sh" -o "$alt" \
    || curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/shared-scripts/hermes-dispatcher-downstream.sh" -o "$alt"; then
    chmod +x "$alt" 2>/dev/null || true
    DS="$alt"
    return 0
  fi
  return 1
}

if ! _resolve_ds; then
  echo "$(date -u +%FT%TZ) ERROR tip#142 missing hermes-dispatcher-downstream.sh (local+CDN)" | tee -a "$LOG" >&2
  exit 127
fi

echo "$(date -u +%FT%TZ) tip#142/#133 launching downstream ds=$DS run_id=$HERMES_RUN_ID zombie=${HERMES_STALL_ZOMBIE}/${HERMES_STALL_ZOMBIE_PASSES}" | tee -a "$LOG"
set +e
bash "$DS" >>"$LOG" 2>&1
rc=$?
set -e
echo "$(date -u +%FT%TZ) tip#133 downstream finished rc=$rc" | tee -a "$LOG"

if [[ "$rc" -eq 0 ]]; then
  date -u +%FT%TZ >"$MARKER"
  echo "$(date -u +%FT%TZ) OK tip#133 wrote success marker $MARKER" | tee -a "$LOG"
else
  echo "$(date -u +%FT%TZ) WARN tip#133 downstream rc=$rc — no success marker (will retry)" | tee -a "$LOG"
fi
exit "$rc"
