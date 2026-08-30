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
echo "tip through #169 (soft-hold tick; CDN TIP_PIN; #161 ENABLE git-push; Zapier GH reconnect; FALLBACK b2b5fc4 tip159)"
echo "Prefer for tonight (if Tailscale+SSH OK):"
echo "  https://github.com/${REPO}/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command"

xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

if ! command -v gh >/dev/null 2>&1; then
  echo "FAILED: gh CLI missing. Install GitHub CLI, then: gh auth login"
  osascript -e 'display notification "Install gh + gh auth login" with title "Hermes Actions enable FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi
