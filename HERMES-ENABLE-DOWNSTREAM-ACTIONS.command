#!/bin/bash
# HERMES-ENABLE-DOWNSTREAM-ACTIONS.command — Right-click → Open on Mac Hermes (not double-click)
# One-shot: install ci/downstream-stall.yml → .github/workflows/ (needs local `gh` with workflow scope),
# then optionally Run workflow. Cloud API tokens usually cannot write .github/workflows/ (404).
# For tonight's stalled canary, prefer HERMES-DOWNSTREAM-RAL793-STALL.command if Tailscale+SSH work.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-enable-downstream-actions-command}"
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
WF_PATH=".github/workflows/downstream-stall.yml"
SRC_URL="https://raw.githubusercontent.com/${REPO}/main/ci/downstream-stall.yml"
RUN_AFTER="${HERMES_RUN_WORKFLOW:-1}"

cd "${TMPDIR:-/tmp}"
echo "=== Hermes ENABLE Downstream Actions ==="
echo "Host: $(hostname) user: $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo: $REPO"
echo "tip through #182 (soft-hold dir tip#182; WAKE tip#180; Phase2 secrets tab tip#179; STALL nag tip#178; Path C tip#177; NAG Raw tip#176; ENABLE tip#175; FALLBACK b2b5fc4 tip159)"
echo "Prefer for tonight (if Tailscale+SSH OK):"
echo "  https://github.com/${REPO}/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command"
