#!/usr/bin/env bash
# Public bootstrap for Hermes Mac land.
# Paste ONE LINE on Mac Hermes (Tailscale up):
#   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
#
# Fetches private moltbot tip via gh (preferred) or git, then runs Mac apply-watch.
# Best-effort Linear STARTED/FAILED beacons (loads ~/.hermes/.env) so failed Mac
# attempts leave evidence on RAL-800 even before tip install runs.
# No Slack rockets. Do not open private GitHub blob URLs in a browser.
set -euo pipefail

CLONE="${HERMES_MOLTBOT_CLONE:-/tmp/moltbot-main-tip-src}"
OWNER_REPO="ilike4movies/moltbot"
SOURCE="${HERMES_MAC_LAND_SOURCE:-public-curl}"

_notify() {
  local title="$1" msg="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
  fi
  echo "== $title: $msg =="
}

# Minimal Linear beacon (parity with tip hermes-moltbot-land-beacon.sh). Never fails caller.
_beacon() {
  local event="$1"
  local detail="${2:-}"
  (
    set +e
    KEY="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
    if [[ -z "$KEY" ]]; then
      for f in \
        "${HOME}/.hermes/.env" \
        "/opt/moltbot/config/secrets.env" \
        "/opt/moltbot/data/cos-hermes/home/.env" \
        "${HOME}/.openclaw/.env"
      do
        [[ -f "$f" ]] || continue
        while IFS= read -r line || [[ -n "$line" ]]; do
          case "$line" in
            ''|\#*) continue ;;
            LINEAR_API_KEY=*|LINEAR_API_TOKEN=*)
              k="${line%%=*}"; v="${line#*=}"
              v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
              if [[ -z "${!k:-}" ]]; then export "$k=$v"; fi
              ;;
          esac
        done < "$f"
      done
      KEY="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
    fi
    [[ -n "$KEY" ]] || exit 0
    TICKET="${HERMES_LAND_TICKET:-RAL-800}"
    HOST="$(hostname 2>/dev/null || echo unknown)"
    USER_NAME="$(whoami 2>/dev/null || echo unknown)"
    WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ "$event" == "started" ]]; then
      BODY=$(printf '## Mac land STARTED\n\nhost=`%s` user=`%s` at `%s`\nsource=`%s`\n\nPublic hermes-mac-land bootstrap beginning (tip fetch → apply-watch). Expect Host surgical-apply OK next.' \
        "$HOST" "$USER_NAME" "$WHEN" "$SOURCE")
    else
      BODY=$(printf '## Mac land FAILED (pre-host)\n\nhost=`%s` user=`%s` at `%s`\nsource=`%s`\ndetail=`%s`\n\nFix gh auth / git / Tailscale+SSH to grok-cos-1, then re-run double-click or public curl from Linear (not Gmail). No rockets.' \
        "$HOST" "$USER_NAME" "$WHEN" "$SOURCE" "${detail:-unknown}")
    fi
    python3 - "$KEY" "$TICKET" "$BODY" <<'PY' 2>/dev/null || true
import json, sys, urllib.request
key, ticket, body = sys.argv[1], sys.argv[2], sys.argv[3]
q1 = {
    "query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id identifier}}}",
    "variables": {"q": ticket},
}
req = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q1).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
with urllib.request.urlopen(req, timeout=8) as r:
    nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
if not nodes:
    raise SystemExit(0)
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
urllib.request.urlopen(req2, timeout=8).read()
print(f"OK land beacon posted to {ticket}")
PY
  ) || true
}

_fetch_tip() {
  rm -rf "$CLONE"
  if command -v gh >/dev/null 2>&1; then
    echo "Fetching tip via gh api tarball…"
    local extract="/tmp/moltbot-tarball-extract-$$"
    rm -rf "$extract"
    mkdir -p "$extract"
    if gh api "repos/$OWNER_REPO/tarball/main" | tar -xz -C "$extract"; then
      local inner
      inner="$(find "$extract" -mindepth 1 -maxdepth 1 -type d | head -1)"
      if [[ -n "$inner" && -d "$inner/shared-scripts" ]]; then
        mv "$inner" "$CLONE"
        rm -rf "$extract"
        echo "OK tip via gh tarball → $CLONE"
        return 0
      fi
    fi
    rm -rf "$extract"
  fi
  echo "WARN: gh tarball failed; trying git SSH"
  if git clone --depth 1 --branch main --single-branch \
      "git@github.com:${OWNER_REPO}.git" "$CLONE"; then
    echo "OK tip via git SSH → $CLONE"
    return 0
  fi
  rm -rf "$CLONE"
  echo "WARN: SSH clone failed; trying HTTPS"
  if git clone --depth 1 --branch main --single-branch \
      "https://github.com/${OWNER_REPO}.git" "$CLONE"; then
    echo "OK tip via HTTPS → $CLONE"
    return 0
  fi
  return 1
}

_notify "Hermes UNBLOCK" "Public curl bootstrap starting…"
_beacon started

if ! _fetch_tip; then
  _beacon failed "Could not fetch moltbot tip (need: gh auth login, or git SSH/HTTPS)"
  _notify "Hermes UNBLOCK FAILED" "Could not fetch moltbot tip (need: gh auth login, or git SSH/HTTPS)"
  echo "ERROR: fetch tip failed. Run: gh auth login" >&2
  exit 1
fi

# Prefer tip beacon after tip is on disk (loads same secrets; marks post-fetch).
if [[ -f "$CLONE/shared-scripts/hermes-moltbot-land-beacon.sh" ]]; then
  bash "$CLONE/shared-scripts/hermes-moltbot-land-beacon.sh" started --source "${SOURCE}-post-fetch" || true
fi

INSTALL="$CLONE/shared-scripts/install-hermes-moltbot-mac-apply-watch.sh"
if [[ ! -f "$INSTALL" ]]; then
  _beacon failed "Tip missing install-hermes-moltbot-mac-apply-watch.sh"
  _notify "Hermes UNBLOCK FAILED" "Tip missing install-hermes-moltbot-mac-apply-watch.sh"
  exit 1
fi

_notify "Hermes UNBLOCK" "Running Mac apply-watch (via-ssh → grok-cos-1)…"
if bash "$INSTALL"; then
  _notify "Hermes UNBLOCK OK" "Expect Linear Host surgical-apply OK"
  echo "OK hermes-mac-land finished"
  exit 0
fi
RC=$?
if [[ -f "$CLONE/shared-scripts/hermes-moltbot-land-beacon.sh" ]]; then
  bash "$CLONE/shared-scripts/hermes-moltbot-land-beacon.sh" failed --source "$SOURCE" --detail "install exited $RC" || true
else
  _beacon failed "install exited $RC"
fi
_notify "Hermes UNBLOCK FAILED" "install exited $RC — check Tailscale + SSH to grok-cos-1"
exit "$RC"
