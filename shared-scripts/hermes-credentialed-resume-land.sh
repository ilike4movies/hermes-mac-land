#!/usr/bin/env bash
# hermes-credentialed-resume-land.sh — Step 1 surgical land + read-only Stage A preflight chain
#
# For credentialed cloud agents or shells with Runtime Secrets at session:
#   TS_AUTHKEY, HERMES_HOST_SSH_PRIVATE_KEY
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
#   bash shared-scripts/hermes-credentialed-resume-land.sh
#
# Does NOT run bounded Stage A activation — operator must follow deployment-packet.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
export HERMES_CLOUD_APPLY_DIR="$DIR"
LOG="$DIR/resume-land.log"

_missing() {
  local missing=()
  [[ -z "${TS_AUTHKEY:-}" ]] && missing+=(TS_AUTHKEY)
  [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && missing+=(HERMES_HOST_SSH_PRIVATE_KEY)
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing secrets: ${missing[*]}" >&2
    echo "Requires credentialed agent on ilike4movies/hermes-mac-land + LEGACY Hermes .11 env." >&2
    echo "See OPERATOR-UNBLOCK.md path A or B. Ooterverse/mobile override cannot receive secrets." >&2
    return 0
  fi
  return 1
}

if _missing; then exit 1; fi

if [[ "${COMPOSER_REPO_URL:-}" == *ooterverse* ]] || [[ "${COMPOSER_REPO_URL:-}" == *Ooterverse* ]]; then
  echo "WARN: Ooterverse repo detected — this script only works if secrets are present in env" >&2
fi

echo "== Hermes credentialed resume land @ $(date -u +%Y-%m-%dT%H:%M:%SZ) ==" | tee -a "$LOG"

if [[ -f "$ROOT/shared-scripts/hermes-cloud-bootstrap-waiter.sh" ]]; then
  bash "$ROOT/shared-scripts/hermes-cloud-bootstrap-waiter.sh" | tee -a "$LOG"
else
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash | tee -a "$LOG"
fi

if [[ -x "$DIR/bridge-secrets-from-env.sh" ]]; then
  bash "$DIR/bridge-secrets-from-env.sh" || true
fi

# Jump-first by default so grok-cos-1 gets the cloud-apply signal watch.
# Direct .11 fallback still works; moltbot #79 installs a local watch there.
# Set HERMES_PREFER_DIRECT_HOST=1 to skip jump (Mac LAN-only path).
export HERMES_PREFER_DIRECT_HOST="${HERMES_PREFER_DIRECT_HOST:-0}"
export HERMES_UPLOAD_TIP_FROM_CALLER=1
export HERMES_POST_APPLY_CANARY="${HERMES_POST_APPLY_CANARY:-RAL-820}"

LAND_SCRIPT="$DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"
[[ -x "$LAND_SCRIPT" ]] || LAND_SCRIPT="$ROOT/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh"

echo "== surgical land (prefer_direct=${HERMES_PREFER_DIRECT_HOST}; jump-first unless 1) ==" | tee -a "$LOG"
if bash "$LAND_SCRIPT" 2>&1 | tee -a "$LOG"; then
  echo "OK surgical land complete" | tee -a "$LOG"
else
  echo "FAIL surgical land — see $LOG" >&2
  exit 1
fi

SRC_PREFLIGHT="$DIR/hermes-stage-a-source-preflight.sh"
[[ -x "$SRC_PREFLIGHT" ]] || SRC_PREFLIGHT="$ROOT/shared-scripts/hermes-stage-a-source-preflight.sh"
LIVE_PREFLIGHT="$DIR/hermes-stage-a-preflight.sh"
[[ -x "$LIVE_PREFLIGHT" ]] || LIVE_PREFLIGHT="$ROOT/shared-scripts/hermes-stage-a-preflight.sh"

echo "== Stage A source preflight (read-only) ==" | tee -a "$LOG"
if [[ -x "$SRC_PREFLIGHT" ]]; then
  bash "$SRC_PREFLIGHT" 2>&1 | tee -a "$LOG" || { echo "FAIL source preflight" >&2; exit 2; }
else
  echo "WARN: source preflight script missing" >&2
fi

echo "== Stage A live preflight (read-only) ==" | tee -a "$LOG"
if [[ -x "$LIVE_PREFLIGHT" ]]; then
  bash "$LIVE_PREFLIGHT" 2>&1 | tee -a "$LOG" || { echo "FAIL live preflight" >&2; exit 3; }
else
  echo "WARN: live preflight script missing" >&2
fi

echo "" | tee -a "$LOG"
echo "NEXT: confirm Host surgical-apply OK on RAL-800 (local cloud-apply watch from moltbot #79)." | tee -a "$LOG"
echo "Then stage RAL-793 inventory contract on .11 (docs/RAL-793-CONTRACT-STAGING.md / hermes-agent-cos #125)." | tee -a "$LOG"
echo "Only then: hermes-now / DISPATCH-NOW RAL-793. Do not DISPATCH without pinned live contract." | tee -a "$LOG"
echo "Success gate: RAL-793 Hermes CLAIMED + inventory evidence. RAL-820 already Done." | tee -a "$LOG"
