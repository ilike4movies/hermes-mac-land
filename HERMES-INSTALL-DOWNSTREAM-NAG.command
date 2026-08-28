#!/bin/bash
# HERMES-INSTALL-DOWNSTREAM-NAG.command — Right-click → Open (not double-click)
# Installs a LaunchAgent that nags every 5 min until issue #1 shows "## Downstream DONE".
# Opens issue #1 + ONE-SHOT URL + Web UI + Tailscale admin/AuthURL; auto-downloads+opens ONE-SHOT
# (HERMES_NAG_AUTO_ONESHOT=0 to require confirm dialog instead). Speaks a short alert when `say` exists.
# No unattended DISPATCH — ONE-SHOT itself still needs Mac session + LINEAR_API_KEY.
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
# Hermes downstream nag — checks issue #1 for Downstream DONE every 5 min.
# Opens status inbox + Tailscale; auto-downloads+opens ONE-SHOT by default.
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

_open_oneshot() {
  dest="${HOME}/Downloads/HERMES-ONE-SHOT-UNBLOCK.command"
  if curl -fsSL "$ONESHOT_URL" -o "$dest"; then
    xattr -d com.apple.quarantine "$dest" 2>/dev/null || true
    chmod +x "$dest" 2>/dev/null || true
    open "$dest" 2>/dev/null || true
    return 0
  fi
  return 1
}

comments="$(_fetch_comments)"
if printf '%s' "$comments" | grep -qF "$MARKER"; then
  launchctl unload "$PLIST" 2>/dev/null || true
  osascript -e 'display notification "Downstream DONE seen — nag unloaded" with title "Hermes" sound name "Hero"' 2>/dev/null || true
  exit 0
fi

osascript -e 'display notification "Still blocked — opening ONE-SHOT / Tailscale / Web UI" with title "Hermes Downstream" sound name "Basso"' 2>/dev/null || true
# Spoken wake (attended Mac session). Opt out: HERMES_NAG_SPEAK=0
if [[ "${HERMES_NAG_SPEAK:-1}" == "1" ]] && command -v say >/dev/null 2>&1; then
  say -v Samantha "Hermes needs ONE-SHOT or Tailscale approve" 2>/dev/null || true
fi
open "$ISSUE_URL" 2>/dev/null || true
open "$ONESHOT_URL" 2>/dev/null || true
open "$WEBUI_WORKFLOW_URL" 2>/dev/null || true
# Also surface cloud Tailscale approve (admin + tip CURRENT_AUTHURL.md).
# Opt out: HERMES_NAG_OPEN_TAILSCALE=0
if [[ "${HERMES_NAG_OPEN_TAILSCALE:-1}" == "1" ]]; then
  open "https://login.tailscale.com/admin/machines" 2>/dev/null || true
  auth=""
  f="/tmp/hermes-nag-current-authurl-$$.md"
  if curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/CURRENT_AUTHURL.md" -o "$f" 2>/dev/null; then
    auth=$(grep -Eo 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' "$f" | head -1 || true)
  fi
  rm -f "$f"
  if [[ -n "$auth" ]]; then
    open "$auth" 2>/dev/null || true
  fi
  # Calendar wake ICS (tip). Opt out: HERMES_NAG_OPEN_ICS=0
  if [[ "${HERMES_NAG_OPEN_ICS:-1}" == "1" ]]; then
    ics="${HOME}/Downloads/HERMES-APPROVE-TAILSCALE.ics"
    if curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/HERMES-APPROVE-TAILSCALE.ics" -o "$ics" 2>/dev/null; then
      open "$ics" 2>/dev/null || true
    fi
  fi
fi
# Default: auto download+open ONE-SHOT (attended). Opt out → confirm dialog: HERMES_NAG_AUTO_ONESHOT=0
if [[ "${HERMES_NAG_AUTO_ONESHOT:-1}" == "1" ]]; then
  _open_oneshot || true
else
  ans="$(osascript -e 'button returned of (display dialog "Hermes downstream still blocked. Run ONE-SHOT now?" buttons {"Not now", "Run ONE-SHOT"} default button "Run ONE-SHOT" with title "Hermes Downstream")' 2>/dev/null || true)"
  if [[ "$ans" == "Run ONE-SHOT" ]]; then
    _open_oneshot || true
  fi
fi
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
  <integer>300</integer>
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
echo "  interval: 5 min — notifies until issue #1 has '## Downstream DONE'"
echo "  note: auto-opens ONE-SHOT by default (HERMES_NAG_AUTO_ONESHOT=0 for confirm-only); never unattended DISPATCH"
echo "Uninstall: launchctl unload $PLIST && rm $PLIST $NAG_BIN"

osascript -e 'display notification "Downstream nag installed (5 min + auto ONE-SHOT)" with title "Hermes" sound name "Glass"' 2>/dev/null || true
if [[ "${HERMES_NAG_NONINTERACTIVE:-0}" == "1" ]]; then
  exit 0
fi
read -r -p "Press Enter to close…" _
