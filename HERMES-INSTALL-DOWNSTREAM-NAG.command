#!/bin/bash
# HERMES-INSTALL-DOWNSTREAM-NAG.command — Right-click → Open (not double-click)
# Installs a LaunchAgent that nags every 30 min until issue #1 shows "## Downstream DONE".
# Does NOT auto-run ONE-SHOT (avoids unattended DISPATCH spam) — opens issue #1 + ONE-SHOT + Web UI workflow editor.
# Uninstall: launchctl unload ~/Library/LaunchAgents/com.hermes.downstream-nag.plist
#            rm ~/Library/LaunchAgents/com.hermes.downstream-nag.plist ~/.hermes/bin/hermes-downstream-nag.sh
set -euo pipefail

REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
PLIST="${HOME}/Library/LaunchAgents/com.hermes.downstream-nag.plist"
NAG_BIN="${HOME}/.hermes/bin/hermes-downstream-nag.sh"
ISSUE_URL="https://github.com/${REPO}/issues/1"
ONESHOT_URL="https://github.com/${REPO}/raw/main/HERMES-ONE-SHOT-UNBLOCK.command"
WEBUI_WORKFLOW_URL="https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml"

xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

mkdir -p "${HOME}/.hermes/bin" "${HOME}/Library/LaunchAgents"

cat > "$NAG_BIN" <<'NAG_EOF'
#!/bin/bash
# Hermes downstream nag — checks issue #1 for Downstream DONE every 30 min.
# Notification-only + opens status inbox (does not execute ONE-SHOT).
set -uo pipefail
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
PLIST="${HOME}/Library/LaunchAgents/com.hermes.downstream-nag.plist"
ISSUE_URL="https://github.com/${REPO}/issues/1"
ONESHOT_URL="https://github.com/${REPO}/raw/main/HERMES-ONE-SHOT-UNBLOCK.command"
WEBUI_WORKFLOW_URL="https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml"
MARKER="## Downstream DONE"

_fetch_comments() {
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh api "repos/${REPO}/issues/1/comments" --paginate --jq '.[].body' 2>/dev/null || true
    return 0
  fi
  curl -fsSL "https://api.github.com/repos/${REPO}/issues/1/comments?per_page=100" 2>/dev/null \
    | python3 -c 'import json,sys; [print(c.get("body","")) for c in json.load(sys.stdin)]' 2>/dev/null || true
}

comments="$(_fetch_comments)"
if printf '%s' "$comments" | grep -qF "$MARKER"; then
  launchctl unload "$PLIST" 2>/dev/null || true
  osascript -e 'display notification "Downstream DONE seen — nag unloaded" with title "Hermes" sound name "Hero"' 2>/dev/null || true
  exit 0
fi

osascript -e 'display notification "Still blocked — ONE-SHOT or Web UI workflow enable" with title "Hermes Downstream" sound name "Basso"' 2>/dev/null || true
open "$ISSUE_URL" 2>/dev/null || true
# Surface ONE-SHOT download + Web UI create-file editor (API cannot write workflows)
open "$ONESHOT_URL" 2>/dev/null || true
open "$WEBUI_WORKFLOW_URL" 2>/dev/null || true
NAG_EOF

chmod +x "$NAG_BIN"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.hermes.downstream-nag</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NAG_BIN}</string>
  </array>
  <key>StartInterval</key>
  <integer>1800</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/.hermes/logs/downstream-nag.out</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/.hermes/logs/downstream-nag.err</string>
</dict>
</plist>
PLIST_EOF

mkdir -p "${HOME}/.hermes/logs"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "OK installed downstream nag LaunchAgent"
echo "  plist: $PLIST"
echo "  script: $NAG_BIN"
echo "  interval: 30 min — notifies until issue #1 has '## Downstream DONE'"
echo "  note: does NOT auto-run ONE-SHOT (opens issue #1 + ONE-SHOT URL + Web UI workflow editor)"
echo "Uninstall: launchctl unload $PLIST && rm $PLIST $NAG_BIN"

osascript -e 'display notification "Downstream nag installed (30 min)" with title "Hermes" sound name "Glass"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
