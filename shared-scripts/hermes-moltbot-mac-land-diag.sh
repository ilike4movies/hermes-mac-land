#!/usr/bin/env bash
# hermes-moltbot-mac-land-diag.sh — collect Mac land status + post to RAL-800
# Also: Desktop file + clipboard + optional gh comment on hermes-mac-land#1
# Double-click via HERMES-DIAGNOSE.command / HERMES-DIAGNOSE-THEN-LAND.command, or:
#   curl -fsSL https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/shared-scripts/hermes-moltbot-mac-land-diag.sh | bash
set -u

JUMP_SSH="${HERMES_JUMP_SSH:-ilike4@100.92.147.61}"
TICKET="${HERMES_LAND_TICKET:-RAL-800}"
GH_STATUS_ISSUE="${HERMES_MAC_LAND_STATUS_ISSUE:-1}"
GH_STATUS_REPO="${HERMES_MAC_LAND_STATUS_REPO:-ilike4movies/hermes-mac-land}"
HOST="$(hostname 2>/dev/null || echo unknown)"
USER_NAME="$(whoami 2>/dev/null || echo unknown)"
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_FILE="$(mktemp /tmp/hermes-mac-land-diag.XXXXXX.txt)"
DESKTOP_FILE="${HOME}/Desktop/HERMES-MAC-LAND-DIAG.txt"

_load_hermes_env() {
  local f
  for f in \
    "${HOME}/.hermes/.env" \
    "/opt/moltbot/config/secrets.env" \
    "/opt/moltbot/data/cos-hermes/home/.env" \
    "${HOME}/.openclaw/.env"
  do
    [[ -f "$f" ]] || continue
    set -a
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        LINEAR_API_KEY=*|LINEAR_API_TOKEN=*)
          key="${line%%=*}"
          val="${line#*=}"
          val="${val%\"}"; val="${val#\"}"
          val="${val%\'}"; val="${val#\'}"
          if [[ -z "${!key:-}" ]]; then
            export "$key=$val"
          fi
          ;;
      esac
    done < "$f"
    set +a
  done
}
_load_hermes_env || true

{
  echo "## Mac land DIAGNOSTIC"
  echo
  echo "host=\`$HOST\` user=\`$USER_NAME\` at \`$WHEN\`"
  echo "source=\`mac-land-diag\`"
  echo
  echo "### Tailscale"
  if command -v tailscale >/dev/null 2>&1; then
    tailscale status --json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print("BackendState:", d.get("BackendState")); s=d.get("Self") or {}; print("Self:", s.get("DNSName") or s.get("HostName") or "")' 2>/dev/null \
      || tailscale status 2>&1 | head -20
  else
    echo "tailscale binary: missing"
  fi
  echo
  echo "### LaunchAgent (hermes)"
  launchctl list 2>/dev/null | grep -i hermes || echo "(no hermes launchctl rows)"
  echo
  echo "### Plists"
  ls -lt "$HOME/Library/LaunchAgents"/com.hermes* 2>/dev/null | head -20 || echo "(no ~/Library/LaunchAgents/com.hermes*)"
  echo
  echo "### Logs"
  ls -lt "$HOME/logs/hermes-mac-apply" 2>/dev/null | head -15 || echo "(no ~/logs/hermes-mac-apply)"
  echo "--- log tails ---"
  for f in "$HOME"/logs/hermes-mac-apply/*.log; do
    [[ -f "$f" ]] || continue
    echo "==== $f (last 25) ===="
    tail -25 "$f" 2>/dev/null || true
  done
  if ! ls "$HOME"/logs/hermes-mac-apply/*.log >/dev/null 2>&1; then
    echo "(no log files)"
  fi
  echo
  echo "### SSH BatchMode → $JUMP_SSH"
  ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new \
    "$JUMP_SSH" 'echo OK_JUMP; hostname; whoami; date -u +%Y-%m-%dT%H:%M:%SZ' 2>&1 | head -40
  echo "ssh_exit=${PIPESTATUS[0]:-?}"
  echo
  echo "### LINEAR key present?"
  if [[ -n "${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}" ]]; then
    echo "LINEAR_API_KEY/TOKEN: yes (loaded)"
  else
    echo "LINEAR_API_KEY/TOKEN: NO — Linear RAL-800 silent unless ~/.hermes/.env has it"
  fi
  echo
  echo "### gh auth?"
  if command -v gh >/dev/null 2>&1; then
    gh auth status 2>&1 | head -8 || true
  else
    echo "gh binary: missing"
  fi
  echo
  echo "### Next"
  echo "If SSH OK but LaunchAgent missing: double-click fresh HERMES-UNBLOCK-APPLY.command (or HERMES-DIAGNOSE-THEN-LAND.command) from https://github.com/ilike4movies/hermes-mac-land"
  echo "If SSH fail: fix Tailscale + SSH BatchMode to grok-cos-1, then re-land."
  echo "No rockets."
} > "$REPORT_FILE" 2>&1

cat "$REPORT_FILE"
echo
echo "=== diagnostic written: $REPORT_FILE ==="

# Always surface locally (works with no Linear key / no gh).
mkdir -p "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
cp "$REPORT_FILE" "$DESKTOP_FILE" 2>/dev/null || true
if command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$REPORT_FILE" 2>/dev/null && echo "OK diagnostic copied to clipboard" || true
fi
if [[ -f "$DESKTOP_FILE" ]]; then
  echo "OK Desktop copy: $DESKTOP_FILE"
  open -a TextEdit "$DESKTOP_FILE" 2>/dev/null || true
fi

POSTED_ANY=0
KEY="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
if [[ -n "$KEY" ]]; then
  BODY="$(cat "$REPORT_FILE")"
  set +e
  python3 - "$KEY" "$TICKET" "$BODY" <<'PY'
import json, sys, urllib.request
key, ticket, body = sys.argv[1], sys.argv[2], sys.argv[3]
if len(body) > 12000:
    body = body[:12000] + "\n\n…(truncated)…"
q1 = {
    "query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id identifier}}}",
    "variables": {"q": ticket},
}
req = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q1).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
with urllib.request.urlopen(req, timeout=12) as r:
    nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
if not nodes:
    raise SystemExit(1)
iid = nodes[0]["id"]
q2 = {
    "query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
    "variables": {"id": iid, "b": body},
}
req2 = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
urllib.request.urlopen(req2, timeout=12).read()
print(f"OK diagnostic posted to {ticket}")
PY
  if [[ $? -eq 0 ]]; then
    POSTED_ANY=1
  else
    echo "WARN: Linear post failed"
  fi
  set -e
else
  echo "WARN: no LINEAR_API_KEY — using Desktop/clipboard/gh fallbacks"
fi

# Public GitHub fallback (no Linear key needed if gh is logged in).
if command -v gh >/dev/null 2>&1; then
  set +e
  BODY_GH="$(cat "$REPORT_FILE")"
  if [[ ${#BODY_GH} -gt 60000 ]]; then
    BODY_GH="${BODY_GH:0:60000}

…(truncated)…"
  fi
  if gh issue comment "$GH_STATUS_ISSUE" --repo "$GH_STATUS_REPO" --body "$BODY_GH" 2>/tmp/hermes-diag-gh.err; then
    echo "OK diagnostic posted to https://github.com/${GH_STATUS_REPO}/issues/${GH_STATUS_ISSUE}"
    POSTED_ANY=1
  else
    echo "WARN: gh issue comment failed (need gh auth write to ${GH_STATUS_REPO})"
    head -5 /tmp/hermes-diag-gh.err 2>/dev/null || true
  fi
  set -e
fi

if [[ "$POSTED_ANY" -eq 0 ]]; then
  echo "WARN: could not post remotely — paste Desktop/clipboard text to RAL-800 / chat"
  say "Hermes diagnostic saved to Desktop. Paste into Linear if needed." 2>/dev/null || true
else
  say "Hermes diagnostic posted." 2>/dev/null || true
fi
exit 0
