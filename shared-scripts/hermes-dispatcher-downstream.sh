#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — credentialed downstream gates after RAL-800/799
#
# Runs (in order):
#   1. RAL-793 contract install (does NOT dispatch)
#   2. RAL-634 starvation verify (--post-linear)
#
# Operator must manually DISPATCH-NOW RAL-793 after contract readback.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
LOG="$DIR/dispatcher-downstream.log"

_contract="$DIR/hermes-ral793-contract-install.sh"
[[ -x "$_contract" ]] || _contract="$ROOT/shared-scripts/hermes-ral793-contract-install.sh"

_starve="$DIR/hermes-ral634-starvation-verify.sh"
[[ -x "$_starve" ]] || _starve="$ROOT/shared-scripts/hermes-ral634-starvation-verify.sh"

if [[ ! -x "$_contract" ]]; then
  echo "fetching hermes-ral793-contract-install.sh from main" | tee -a "$LOG"
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh \
    -o "$DIR/hermes-ral793-contract-install.sh"
  chmod +x "$DIR/hermes-ral793-contract-install.sh"
  _contract="$DIR/hermes-ral793-contract-install.sh"
fi

if [[ ! -x "$_starve" ]]; then
  echo "fetching hermes-ral634-starvation-verify.sh from main" | tee -a "$LOG"
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh \
    -o "$DIR/hermes-ral634-starvation-verify.sh"
  chmod +x "$DIR/hermes-ral634-starvation-verify.sh"
  _starve="$DIR/hermes-ral634-starvation-verify.sh"
fi

echo "== Hermes dispatcher downstream @ $(date -u +%Y-%m-%dT%H:%M:%SZ) ==" | tee -a "$LOG"

echo "== Step 1: RAL-793 contract install ==" | tee -a "$LOG"
bash "$_contract" 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "== Step 2: RAL-634 starvation verify ==" | tee -a "$LOG"
bash "$_starve" --post-linear 2>&1 | tee -a "$LOG" || {
  echo "WARN: RAL-634 verify failed — see $LOG" | tee -a "$LOG"
}

echo "" | tee -a "$LOG"
echo "NEXT (manual — script does NOT dispatch):" | tee -a "$LOG"
echo "  1. Confirm orchestrator registry hash pin if embedded" | tee -a "$LOG"
echo "  2. DISPATCH-NOW RAL-793 or hermes-now on RAL-793" | tee -a "$LOG"
echo "  3. Expect inventory evidence on RAL-793 (evidence/RAL-793-inventory.md)" | tee -a "$LOG"
echo "  4. Do NOT treat prior WORK-PACKET-DONE as objective closure" | tee -a "$LOG"
