#!/bin/bash
# HERMES-DIAGNOSE-THEN-LAND.command — one double-click on Mac Hermes
# 1) Posts/saves Mac land DIAGNOSTIC (Linear + Desktop/clipboard + gh#1 fallback)
# 2) Immediately runs public via-ssh land (no second download)
# Fetches pinned tip SHA first (survives a bad main tip / CDN lag).
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-diagnose-then-land}"
PIN="${HERMES_MAC_LAND_PIN:-2d4e8d3015902c9fa8b5a0766f50dcf080ae3b29}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DIAGNOSE → LAND (one double-click) pin=$PIN ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Diagnose then land tip on .11…" with title "Hermes DIAGNOSE→LAND" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

_fetch() {
  local out="$1" needle="$2"
  shift 2
  local url
  rm -f "$out"
  for url in "$@"; do
    echo "Trying fetch: $url"
    if curl -fsSL "$url" -o "$out"; then
      if grep -q 'PLACEHOLDER' "$out" 2>/dev/null && ! grep -q "$needle" "$out" 2>/dev/null; then
        echo "WARN: PLACEHOLDER body; trying next mirror"
        rm -f "$out"
        continue
      fi
      if grep -q "$needle" "$out" 2>/dev/null; then
        echo "OK fetched: $url"
        chmod +x "$out"
        return 0
      fi
      echo "WARN: unexpected body; trying next mirror"
      rm -f "$out"
    fi
  done
  return 1
}

DIAG="/tmp/hermes-mac-land-diag-fetched-$$.sh"
LAND="/tmp/hermes-mac-land-fetched-$$.sh"

if ! _fetch "$DIAG" 'Mac land DIAGNOSTIC' \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/shared-scripts/hermes-moltbot-mac-land-diag.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-moltbot-mac-land-diag.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@${PIN}/shared-scripts/hermes-moltbot-mac-land-diag.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/shared-scripts/hermes-moltbot-mac-land-diag.sh"
then
  echo "FAILED: could not download diag script"
  osascript -e 'display notification "Diag download FAILED." with title "Hermes DIAGNOSE→LAND FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

echo "--- DIAGNOSE ---"
set +e
bash "$DIAG"
DIAG_RC=$?
set -e
echo "diag_exit=$DIAG_RC"

if ! _fetch "$LAND" 'via-ssh only' \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/hermes-mac-land.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@${PIN}/hermes-mac-land.sh" \
  "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh"
then
  # older tip used different marker
  if ! _fetch "$LAND" 'no private moltbot' \
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/hermes-mac-land.sh" \
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh" \
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@${PIN}/hermes-mac-land.sh" \
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh"
  then
    echo "FAILED: could not download land script"
    osascript -e 'display notification "Land download FAILED." with title "Hermes DIAGNOSE→LAND FAILED" sound name "Basso"' 2>/dev/null || true
    read -r -p "Press Enter to close…" _
    exit 1
  fi
fi

echo "--- LAND ---"
set +e
bash "$LAND"
LAND_RC=$?
set -e
if [[ "$LAND_RC" -eq 0 ]]; then
  echo "OK diagnose→land finished"
  osascript -e 'display notification "Land finished. Check Linear / GitHub issue #1." with title "Hermes DIAGNOSE→LAND OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes diagnose and land complete." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi
echo "FAILED: land exited $LAND_RC (diag_exit=$DIAG_RC)"
osascript -e 'display notification "Land FAILED. See Terminal / Desktop diag." with title "Hermes DIAGNOSE→LAND FAILED" sound name "Basso"' 2>/dev/null || true
say "Hermes land failed." 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit "$LAND_RC"
