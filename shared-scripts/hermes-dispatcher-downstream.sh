#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — credentialed downstream gates after RAL-800/799
#
# Runs (in order):
#   0. RAL-793 run inspect (optional; when HERMES_RUN_ID set or HERMES_AUTO_INSPECT_RAL793=1)
#   1. RAL-793 contract install (--post-linear)
#   2. governed stack-apply (moltbot main → .11; HERMES_AUTO_STACK_APPLY=0 to skip)
#   3. DISPATCH-NOW RAL-793 via Linear comment (default on; HERMES_AUTO_DISPATCH_RAL793=0 to skip)
#      stall_recovery=1 → two DISPATCH-NOW passes (~90s) to clear SLA-stale CLAIM then reopen
#      zombie reclaim (age≥1h) → three DISPATCH-NOW passes (~120s) for ultra-stale CLAIM
#      FAIL-CLOSED if AUTO_DISPATCH=1 and no DISPATCH-NOW post succeeds (needs LINEAR_API_KEY)
#   4. RAL-634 starvation verify (--post-linear)
#   5. optional inventory wait (stall default on) — poll run-inspect until evidence is real
#
# Machine status: posts STARTED/DONE/FAILED/PARTIAL to hermes-mac-land GitHub issue #1 when `gh` available (preflight skips beacon).
#
# Usage:
#   HERMES_AUTO_SURGICAL_LAND=0 curl -fsSL .../hermes-dispatcher-downstream.sh | bash
#   (auto-pins stall run + stack-apply=0 + stall_recovery=1 when run matches default;
#    .11 verified at #110 tip — set HERMES_AUTO_STACK_APPLY=1 only if host drifts)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
LOG="$DIR/dispatcher-downstream.log"
LINEAR_TICKET="${HERMES_RAL793_LINEAR_TICKET:-RAL-793}"
LINEAR_ISSUE_ID="${HERMES_RAL793_LINEAR_ISSUE_ID:-963472c8-cc84-426a-9ed6-79e08566353a}"
DEFAULT_STALL_RUN_ID="${HERMES_DEFAULT_STALL_RUN_ID:-20260826T232521106484Z-2954673}"

# Downstream-only: auto-pin stalled canary when HERMES_AUTO_SURGICAL_LAND=0 (#36 parity)
if [[ "${HERMES_AUTO_SURGICAL_LAND:-}" == "0" ]] && [[ -z "${HERMES_RUN_ID:-}" ]]; then
  export HERMES_RUN_ID="$DEFAULT_STALL_RUN_ID"
  echo "INFO: HERMES_RUN_ID defaulted to stalled canary run $HERMES_RUN_ID" >&2
fi

AUTO_DISPATCH="${HERMES_AUTO_DISPATCH_RAL793:-1}"
# Stall run: stack-apply defaults OFF — .11 verified at #110 tip (b3b82bf2… / a535cb7) @ 00:05Z.
if [[ "${HERMES_RUN_ID:-}" == "$DEFAULT_STALL_RUN_ID" ]]; then
  AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
  STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
  WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
else
  AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-1}"
  STALL_RECOVERY="${HERMES_STALL_RECOVERY:-}"
  WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-0}"
fi
AUTO_INSPECT="${HERMES_AUTO_INSPECT_RAL793:-}"
INSPECT_OUT="$DIR/ral793-inspect.out"
GH_STATUS_ISSUE="${HERMES_MAC_LAND_STATUS_ISSUE:-1}"
GH_STATUS_REPO="${HERMES_MAC_LAND_STATUS_REPO:-ilike4movies/hermes-mac-land}"
STARVE_RC=0
INVENTORY_RC=0
INVENTORY_WAIT_SECS="${HERMES_INVENTORY_WAIT_SECS:-900}"
INVENTORY_POLL_SECS="${HERMES_INVENTORY_POLL_SECS:-30}"
