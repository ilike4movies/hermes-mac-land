#!/bin/bash
# HERMES-UNBLOCK-APPLY.command — double-click on Mac Hermes
# Public repo: https://github.com/ilike4movies/hermes-mac-land
# Download this file from GitHub (public — no private blob 404), then double-click.
# Requires: Tailscale up + SSH BatchMode to grok-cos-1 + gh auth (or git) to private moltbot.
# Public hermes-mac-land.sh posts best-effort Linear STARTED/FAILED on RAL-800.
# Prefer jsDelivr (fresher than raw.githubusercontent.com CDN for tip).
# Fetch-once with mirrors — never re-run land if the script itself fails.
set -euo pipefail

export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-command}"

cd "${TMPDIR:-/tmp}"
echo "=== Hermes Mac land (public bootstrap) ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Landing tip interrupt/apply on .11…" with title "Hermes UNBLOCK" sound name "Glass"' 2>/dev/null || true

# Clear quarantine if downloaded from browser.
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

SCRIPT="/tmp/hermes-mac-land-fetched-$$.sh"
rm -f "$SCRIPT"
FETCHED=""
for url in \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@36c63390adbad78aff48884b90ed8e0c8bc4b7ad/hermes-mac-land.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/36c63390adbad78aff48884b90ed8e0c8bc4b7ad/hermes-mac-land.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh"
do
  echo "Trying fetch: $url"
  if curl -fsSL "$url" -o "$SCRIPT"; then
    # Prefer bodies that include the early Linear beacon; accept tip install marker as fallback.
    if grep -q '_beacon' "$SCRIPT" 2>/dev/null || grep -q 'Mac apply-watch' "$SCRIPT" 2>/dev/null; then
      FETCHED="$url"
      break
    fi
    echo "WARN: fetched body looked incomplete; trying next mirror"
    rm -f "$SCRIPT"
  fi
done

if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
  echo "FAILED: could not download hermes-mac-land.sh from any mirror"
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
