#!/bin/bash
# HERMES-UNBLOCK-APPLY.command — double-click on Mac Hermes
# Public repo: https://github.com/ilike4movies/hermes-mac-land
# Download this file from GitHub (public — no private blob 404), then double-click.
# Requires: Tailscale up + SSH BatchMode to grok-cos-1 + gh auth (or git) to private moltbot.
set -euo pipefail

cd "${TMPDIR:-/tmp}"
echo "=== Hermes Mac land (public bootstrap) ==="
echo "Host: $(hostname)  user: $(whoami)  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
osascript -e 'display notification "Landing tip interrupt/apply on .11…" with title "Hermes UNBLOCK" sound name "Glass"' 2>/dev/null || true

# Clear quarantine if downloaded from browser.
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

if curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash; then
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
