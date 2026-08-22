#!/bin/bash
# HERMES-DIAGNOSE-THEN-LAND.command — one double-click on Mac Hermes
# Prefers a single GitHub archive tarball (co-located diag+via-ssh; survives bad
# floating main / CDN lag). Falls back to per-file raw/CDN fetches.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-diagnose-then-land-tarball}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DIAGNOSE → LAND (tarball-first) pin=$PIN ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Diagnose then land tip on .11…" with title "Hermes DIAGNOSE→LAND" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

BUNDLE=""
_try_tarball() {
  local pin="$1" dest tgz
  dest="/tmp/hermes-mac-land-src-$$"
  tgz="/tmp/hermes-mac-land-$$.tgz"
  rm -rf "$dest" "$tgz"
  mkdir -p "$dest"
  echo "Trying archive pin=$pin"
  if ! curl -fsSL "https://codeload.github.com/ilike4movies/hermes-mac-land/tar.gz/${pin}" -o "$tgz"; then
    if ! curl -fsSL "https://github.com/ilike4movies/hermes-mac-land/archive/${pin}.tar.gz" -o "$tgz"; then
      return 1
    fi
  fi
  if ! tar -tzf "$tgz" >/dev/null 2>&1; then
    echo "WARN: bad tarball"
    rm -f "$tgz"
    return 1
  fi
  tar -xzf "$tgz" -C "$dest"
  # archive extracts to hermes-mac-land-<sha>/
  local root
  root="$(find "$dest" -maxdepth 1 -type d -name 'hermes-mac-land-*' | head -1)"
  if [[ -z "$root" || ! -f "$root/shared-scripts/hermes-moltbot-mac-land-diag.sh" ]]; then
    echo "WARN: tarball missing diag"
    return 1
  fi
  if grep -q '^PLACEHOLDER$' "$root/shared-scripts/hermes-moltbot-mac-land-diag.sh" 2>/dev/null && \
     ! grep -q 'Mac land DIAGNOSTIC' "$root/shared-scripts/hermes-moltbot-mac-land-diag.sh" 2>/dev/null; then
    echo "WARN: PLACEHOLDER diag in tarball"
    return 1
  fi
  if [[ ! -f "$root/hermes-mac-land.sh" ]]; then
    echo "WARN: tarball missing land"
    return 1
  fi
  BUNDLE="$root"
  echo "OK tarball vendor → $BUNDLE"
  return 0
}

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

DIAG=""
LAND=""

if _try_tarball "$PIN" || _try_tarball "main"; then
  DIAG="$BUNDLE/shared-scripts/hermes-moltbot-mac-land-diag.sh"
  LAND="$BUNDLE/hermes-mac-land.sh"
  chmod +x "$DIAG" "$LAND" "$BUNDLE"/shared-scripts/*.sh 2>/dev/null || true
else
  echo "WARN: tarball path failed — falling back to per-file fetch"
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
  if ! _fetch "$LAND" 'via-ssh only' \
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/hermes-mac-land.sh" \
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh" \
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@${PIN}/hermes-mac-land.sh" \
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh"
  then
    if ! _fetch "$LAND" 'no private moltbot' \
      "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/hermes-mac-land.sh" \
      "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh"
    then
      echo "FAILED: could not download land script"
      osascript -e 'display notification "Land download FAILED." with title "Hermes DIAGNOSE→LAND FAILED" sound name "Basso"' 2>/dev/null || true
      read -r -p "Press Enter to close…" _
      exit 1
    fi
  fi
fi

echo "--- DIAGNOSE ---"
set +e
bash "$DIAG"
DIAG_RC=$?
set -e
echo "diag_exit=$DIAG_RC"

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
