#!/bin/bash
# HERMES-DIAGNOSE-THEN-LAND.command — SELF-CONTAINED one double-click
# Embeds diag + via-ssh vendor so land works even if raw/CDN fetch fails after download.
# Network fetch remains as fallback if embed extract fails.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-diagnose-then-land-embedded}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DIAGNOSE → LAND (self-contained) ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Diagnose then land tip on .11 (embedded)…" with title "Hermes DIAGNOSE→LAND" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

BUNDLE="/tmp/hermes-dtl-bundle-$$"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/shared-scripts"

_extract() {
  local name="$1" out="$2"
  local b64f
  b64f="$(mktemp /tmp/hermes-embed-XXXXXX.b64)"
  case "$name" in
  DIAG)
    cat >"$b64f" <<'B64'
PLACEHOLDER_TRUNCATED_FOR_MCP
B64
    ;;
  esac
}
