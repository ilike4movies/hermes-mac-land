#!/bin/bash
# HERMES-DIAGNOSE.command — double-click on Mac Hermes
# Posts LaunchAgent / Tailscale / SSH status to Linear RAL-800 when possible.
# Always writes ~/Desktop/HERMES-MAC-LAND-DIAG.txt + clipboard; gh → issue #1 fallback.
# Fetches pinned tip SHA first (survives a bad main tip / CDN lag).
set -euo pipefail
PIN="${HERMES_MAC_LAND_PIN:-2d4e8d3015902c9fa8b5a0766f50dcf080ae3b29}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes Mac land DIAGNOSTIC pin=$PIN ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Collecting Mac land diagnostic…" with title "Hermes DIAGNOSE" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

SCRIPT="/tmp/hermes-mac-land-diag-fetched-$$.sh"
rm -f "$SCRIPT"
FETCHED=""
for url in \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/shared-scripts/hermes-moltbot-mac-land-diag.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-moltbot-mac-land-diag.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@${PIN}/shared-scripts/hermes-moltbot-mac-land-diag.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/shared-scripts/hermes-moltbot-mac-land-diag.sh"
do
  echo "Trying fetch: $url"
  if curl -fsSL "$url" -o "$SCRIPT"; then
    if grep -q 'PLACEHOLDER' "$SCRIPT" 2>/dev/null && ! grep -q 'Mac land DIAGNOSTIC' "$SCRIPT" 2>/dev/null; then
      echo "WARN: PLACEHOLDER body; trying next mirror"
      rm -f "$SCRIPT"
      continue
    fi
    if grep -q 'Mac land DIAGNOSTIC' "$SCRIPT" 2>/dev/null; then
      FETCHED="$url"
      break
    fi
    echo "WARN: unexpected body; trying next mirror"
    rm -f "$SCRIPT"
  fi
done

if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
  echo "FAILED: could not download tip hermes-moltbot-mac-land-diag.sh"
  osascript -e 'display notification "Download FAILED." with title "Hermes DIAGNOSE FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

echo "OK fetched from: $FETCHED"
chmod +x "$SCRIPT"
set +e
bash "$SCRIPT"
RC=$?
set -e
if [[ "$RC" -eq 0 ]]; then
  osascript -e 'display notification "Diagnostic done. Check Linear RAL-800, Desktop file, or GitHub #1." with title "Hermes DIAGNOSE OK" sound name "Hero"' 2>/dev/null || true
else
  osascript -e 'display notification "Diagnostic finished with errors — see Terminal / Desktop." with title "Hermes DIAGNOSE" sound name "Basso"' 2>/dev/null || true
fi
read -r -p "Press Enter to close…" _
exit "$RC"
