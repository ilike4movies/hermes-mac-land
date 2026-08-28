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

if ! gh auth status >/dev/null 2>&1; then
  echo "FAILED: gh not logged in. Run: gh auth login"
  osascript -e 'display notification "Run gh auth login" with title "Hermes Actions enable FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

echo "OK gh auth present"
osascript -e 'display notification "Installing workflow via local gh…" with title "Hermes Actions enable" sound name "Glass"' 2>/dev/null || true

EXISTING_SHA=""
if EXISTING_SHA=$(gh api "repos/${REPO}/contents/${WF_PATH}" --jq .sha 2>/dev/null); then
  echo "OK workflow already on main (sha=${EXISTING_SHA:0:12}…)"
else
  echo "Installing ${WF_PATH} from ci/downstream-stall.yml…"
  SRC_FILE="/tmp/hermes-downstream-stall-yml-$$.yml"
  curl -fsSL "$SRC_URL" -o "$SRC_FILE"
  if ! grep -q 'workflow_dispatch' "$SRC_FILE" || ! grep -q 'hermes-dispatcher-downstream.sh' "$SRC_FILE"; then
    echo "FAILED: downloaded workflow looks incomplete"
    rm -f "$SRC_FILE"
    exit 1
  fi
  # macOS base64 has no -w0
  B64=$(base64 < "$SRC_FILE" | tr -d '\n')
  rm -f "$SRC_FILE"
  if ! gh api --method PUT "repos/${REPO}/contents/${WF_PATH}" \
      -f message='ci: enable downstream-stall workflow under .github/workflows' \
      -f content="$B64" \
      -f branch=main >/tmp/hermes-wf-put.json 2>/tmp/hermes-wf-put.err; then
    echo "FAILED: could not write ${WF_PATH}"
    echo "Likely missing 'workflow' scope on this gh token."
    echo "Fix options:"
    echo "  1) gh auth refresh -h github.com -s workflow"
    echo "  2) Web UI: copy ci/downstream-stall.yml → ${WF_PATH} on main"
    echo "     https://github.com/${REPO}/new/main?filename=${WF_PATH}"
    cat /tmp/hermes-wf-put.err 2>/dev/null || true
    open "https://github.com/${REPO}/new/main?filename=${WF_PATH}" 2>/dev/null || true
    osascript -e 'display notification "Need workflow scope or web UI paste" with title "Hermes Actions enable FAILED" sound name "Basso"' 2>/dev/null || true
    read -r -p "Press Enter to close…" _
    exit 1
  fi
  echo "OK installed ${WF_PATH} on main"
fi

echo ""
echo "Action secrets required (Settings → Secrets and variables → Actions):"
echo "  TS_AUTHKEY"
echo "  HERMES_HOST_SSH_PRIVATE_KEY"
echo "  LINEAR_API_KEY"
echo "Secrets UI: https://github.com/${REPO}/settings/secrets/actions"

if [[ "$RUN_AFTER" != "1" ]]; then
  echo "HERMES_RUN_WORKFLOW=0 — skipping workflow run"
  osascript -e 'display notification "Workflow installed. Add secrets then Run." with title "Hermes Actions enable OK" sound name "Hero"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi

echo ""
echo "Triggering workflow_dispatch…"
if gh workflow run downstream-stall.yml --repo "$REPO"; then
  echo "OK workflow_dispatch accepted"
  echo "Watch: https://github.com/${REPO}/actions"
  echo "Inbox: https://github.com/${REPO}/issues/1"
  open "https://github.com/${REPO}/actions" 2>/dev/null || true
  osascript -e 'display notification "Workflow started. Watch Actions + issue #1." with title "Hermes Actions enable OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes Actions downstream started. Watch GitHub." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi

echo "FAILED: gh workflow run (workflow may be new / secrets missing / Actions disabled)"
echo "Manual: Actions → Downstream stall recovery → Run workflow"
open "https://github.com/${REPO}/actions" 2>/dev/null || true
open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
osascript -e 'display notification "Install OK; run failed — check secrets/Actions" with title "Hermes Actions enable PARTIAL" sound name "Basso"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit 1
