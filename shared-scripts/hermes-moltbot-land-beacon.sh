#!/usr/bin/env bash
# hermes-moltbot-land-beacon.sh - best-effort Linear land STARTED/FAILED beacon
#
# Posts to HERMES_LAND_TICKET (default RAL-800) when Mac/Terminal/via-ssh/jump
# land begins or fails before host surgical-apply can report. Never fails the caller.
#
# Usage:
#   bash shared-scripts/hermes-moltbot-land-beacon.sh started [--source NAME]
#   bash shared-scripts/hermes-moltbot-land-beacon.sh failed --detail "ssh timeout" [--source NAME]
#
# Needs LINEAR_API_KEY or LINEAR_API_TOKEN (env or Hermes secret files; optional).
set -u
EVENT="${1:-}"
SOURCE="terminal"
DETAIL=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="${2:-unknown}"; shift 2 ;;
    --detail) DETAIL="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Best-effort load Hermes secrets so Terminal paste works without export.
_load_hermes_env() {
  local f
  for f in \
    "${HOME}/.hermes/.env" \
    "/opt/moltbot/config/secrets.env" \
    "/opt/moltbot/data/cos-hermes/home/.env" \
    "${HOME}/.openclaw/.env"
  do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC1090
    set -a
    # Only import LINEAR_* lines to avoid clobbering unrelated env.
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

KEY="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
if [[ -z "$KEY" || -z "$EVENT" ]]; then
  exit 0
fi

TICKET="${HERMES_LAND_TICKET:-RAL-800}"
HOST="$(hostname 2>/dev/null || echo unknown)"
USER_NAME="$(whoami 2>/dev/null || echo unknown)"
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$EVENT" == "started" ]]; then
  BODY=$(printf '## Mac land STARTED\n\nhost=`%s` user=`%s` at `%s`\nsource=`%s`\n\nRunning tip land path (Terminal/via-ssh/jump). Expect Host surgical-apply OK next.' \
    "$HOST" "$USER_NAME" "$WHEN" "$SOURCE")
elif [[ "$EVENT" == "failed" ]]; then
  BODY=$(printf '## Mac land FAILED (pre-host)\n\nhost=`%s` user=`%s` at `%s`\nsource=`%s`\ndetail=`%s`\n\nFix SSH/Tailscale to grok-cos-1, then re-run Terminal land. No rockets.' \
    "$HOST" "$USER_NAME" "$WHEN" "$SOURCE" "${DETAIL:-unknown}")
else
  exit 0
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
exit 0
