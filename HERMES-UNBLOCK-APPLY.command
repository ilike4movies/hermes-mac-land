#!/bin/bash
# HERMES-UNBLOCK-APPLY.command — double-click on Mac Hermes
# Public: https://github.com/ilike4movies/hermes-mac-land
# No private moltbot auth on Mac — via-ssh to grok-cos-1 does the tip clone.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-command}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes Mac land (public via-ssh bootstrap) ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Landing tip interrupt/apply on .11…" with title "Hermes UNBLOCK" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

SCRIPT="/tmp/hermes-mac-land-fetched-$$.sh"
rm -f "$SCRIPT"
FETCHED=""
for url in \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh"
do
  echo "Trying fetch: $url"
  if curl -fsSL "$url" -o "$SCRIPT"; then
    if grep -q 'no private moltbot' "$SCRIPT" 2>/dev/null || grep -q 'via-ssh only' "$SCRIPT" 2>/dev/null; then
      FETCHED="$url"
      break
    fi
    echo "WARN: stale body; trying next mirror"
    rm -f "$SCRIPT"
  fi
done

if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
  echo "FAILED: could not download tip hermes-mac-land.sh"
  osascript -e 'display notification "Download FAILED." with title "Hermes UNBLOCK FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

echo "OK fetched from: $FETCHED"
if bash "$SCRIPT"; then
  echo "OK hermes-mac-land finished"
  osascript -e 'display notification "Land finished. Check Linear for Host surgical-apply OK." with title "Hermes UNBLOCK OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes land complete. Check Linear." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi
RC=$?
echo "FAILED: hermes-mac-land exited $RC"
osascript -e 'display notification "Land FAILED. See Terminal." with title "Hermes UNBLOCK FAILED" sound name "Basso"' 2>/dev/null || true
say "Hermes land failed." 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit "$RC"
