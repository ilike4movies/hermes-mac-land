#!/bin/bash
# HERMES-DOWNSTREAM-ONLY.command — double-click on Mac Hermes
# Runs RAL-793 contract install + RAL-634 starvation verify (skips land when gates closed).
# Does NOT dispatch — post DISPATCH-NOW RAL-793 manually after contract readback.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-downstream-only-command}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DOWNSTREAM ONLY (RAL-793 contract + RAL-634 verify) pin=$PIN ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Running downstream gates on .11…" with title "Hermes DOWNSTREAM" sound name "Glass"' 2>/dev/null || true
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
    if grep -q 'RAL-793 contract install' "$SCRIPT" 2>/dev/null; then
      FETCHED="$url"
      break
    fi
    rm -f "$SCRIPT"
  fi
done

if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
  echo "FAILED: could not download hermes-dispatcher-downstream.sh"
  osascript -e 'display notification "Download FAILED." with title "Hermes DOWNSTREAM FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

chmod +x "$SCRIPT"
echo "OK fetched from: $FETCHED"
if bash "$SCRIPT"; then
  echo "OK downstream gates finished"
  echo "NEXT (manual): DISPATCH-NOW RAL-793 after contract readback on Linear"
  osascript -e 'display notification "Downstream OK. Post DISPATCH-NOW RAL-793." with title "Hermes DOWNSTREAM OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes downstream complete. Dispatch RAL-793 manually." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi
RC=$?
echo "FAILED: downstream exited $RC"
osascript -e 'display notification "Downstream FAILED. See Terminal." with title "Hermes DOWNSTREAM FAILED" sound name "Basso"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit "$RC"
