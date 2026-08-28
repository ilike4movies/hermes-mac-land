#!/bin/bash
# HERMES-DOWNSTREAM-RAL793-STALL.command — Right-click → Open on Mac Hermes (not double-click)
# Pins stalled run 20260826T232521106484Z-2954673 and runs full downstream chain:
# inspect → contract install → (stack-apply skipped — .11 at #110 tip) → dual DISPATCH-NOW
# → RAL-634 verify → inventory wait (~3 min, fail-closed if DISPATCH/Linear key missing).
# Fetches hermes-dispatcher-downstream.sh from main at runtime.
# Posts machine status to GitHub issue #1 when gh is available.
# Requires: Tailscale up + SSH to .11 + LINEAR_API_KEY in ~/.hermes/.env (for DISPATCH-NOW).
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-downstream-ral793-stall-command}"
export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
export HERMES_AUTO_SURGICAL_LAND=0
export HERMES_AUTO_INSPECT_RAL793=1
# .11 verified at #110 tip (SHA b3b82bf2… / merge a535cb7) @ 00:05Z — skip stack-apply.
# Set HERMES_AUTO_STACK_APPLY=1 only if host drifts from main.
export HERMES_AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DOWNSTREAM RAL-793 STALL (run=$HERMES_RUN_ID) pin=$PIN ==="
echo "stack-apply=$HERMES_AUTO_STACK_APPLY stall_recovery=$HERMES_STALL_RECOVERY wait_inventory=$HERMES_WAIT_INVENTORY"
echo "Host: $(hostname) user: $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Status inbox: https://github.com/ilike4movies/hermes-mac-land/issues/1"
osascript -e 'display notification "Inspecting stalled RAL-793 run on .11…" with title "Hermes STALL downstream" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

SCRIPT="/tmp/hermes-dispatcher-downstream-fetched-$$.sh"
rm -f "$SCRIPT"
FETCHED=""
for url in \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/shared-scripts/hermes-dispatcher-downstream.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh"
do
  echo "Trying fetch: $url"
  if curl -fsSL "$url" -o "$SCRIPT"; then
    if grep -q 'RAL-793 run inspect' "$SCRIPT" 2>/dev/null \
       && grep -q 'stack-apply' "$SCRIPT" 2>/dev/null \
       && grep -q 'DISPATCH-NOW' "$SCRIPT" 2>/dev/null \
       && grep -q 'RAL-634 starvation verify' "$SCRIPT" 2>/dev/null \
       && grep -q '_post_github_status' "$SCRIPT" 2>/dev/null \
       && grep -q 'STALL_DISPATCH_PASSES' "$SCRIPT" 2>/dev/null \
       && grep -q 'WAIT_INVENTORY' "$SCRIPT" 2>/dev/null \
       && grep -q 'fail-closed' "$SCRIPT" 2>/dev/null; then
      FETCHED="$url"
      break
    fi
    rm -f "$SCRIPT"
  fi
done

if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
  echo "FAILED: could not download hermes-dispatcher-downstream.sh (need inspect + stack-apply + dual-dispatch + inventory-wait + GitHub beacon chain)"
  osascript -e 'display notification "Download FAILED." with title "Hermes STALL downstream FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

chmod +x "$SCRIPT"
echo "OK fetched from: $FETCHED"
if bash "$SCRIPT"; then
  echo "OK downstream gates finished for run $HERMES_RUN_ID"
  echo "NEXT: confirm Linear inventory evidence (not WORK-PACKET-DONE alone)"
  echo " watch GitHub issue #1 for Downstream DONE receipt"
  osascript -e 'display notification "Stall downstream OK. Watch Linear + GitHub #1." with title "Hermes STALL downstream OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes stall downstream complete. Watch Linear for inventory evidence." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi
RC=$?
echo "FAILED: downstream exited $RC"
osascript -e 'display notification "Stall downstream FAILED. See Terminal." with title "Hermes STALL downstream FAILED" sound name "Basso"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit "$RC"
