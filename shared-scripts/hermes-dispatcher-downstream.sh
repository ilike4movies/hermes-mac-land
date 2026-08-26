#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — credentialed downstream gates after RAL-800/799
#
# Runs (in order):
#   1. RAL-793 contract install (--post-linear)
#   2. DISPATCH-NOW RAL-793 via Linear comment (default on; HERMES_AUTO_DISPATCH_RAL793=0 to skip)
#   3. RAL-634 starvation verify (--post-linear)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
LOG="$DIR/dispatcher-downstream.log"
LINEAR_TICKET="${HERMES_RAL793_LINEAR_TICKET:-RAL-793}"
LINEAR_ISSUE_ID="${HERMES_RAL793_LINEAR_ISSUE_ID:-963472c8-cc84-426a-9ed6-79e08566353a}"
AUTO_DISPATCH="${HERMES_AUTO_DISPATCH_RAL793:-1}"

_contract="$DIR/hermes-ral793-contract-install.sh"
[[ -x "$_contract" ]] || _contract="$ROOT/shared-scripts/hermes-ral793-contract-install.sh"

_starve="$DIR/hermes-ral634-starvation-verify.sh"
[[ -x "$_starve" ]] || _starve="$ROOT/shared-scripts/hermes-ral634-starvation-verify.sh"

_load_hermes_ssh_env() {
  local f key val
  for f in "${HOME}/.hermes/.env" /opt/moltbot/config/secrets.env "${HOME}/.openclaw/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        LINEAR_API_KEY=*|LINEAR_API_TOKEN=*)
          key="${line%%=*}"
          val="${line#*=}"
          val="${val%\"}"; val="${val#\"}"
          val="${val%\'}"; val="${val#\'}"
          [[ -z "${!key:-}" ]] && export "$key=$val"
          ;;
      esac
    done < "$f"
  done
}

_post_linear_comment() {
  local body="$1"
  local key="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
  [[ -n "$key" ]] || return 1
  python3 - "$key" "$LINEAR_TICKET" "${LINEAR_ISSUE_ID:-}" "$body" <<'PY' 2>/dev/null
import json, sys, urllib.request
key, ticket, issue_id, body = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
iid = issue_id.strip()
if not iid:
    q1 = {"query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id}}}", "variables": {"q": ticket}}
    req = urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q1).encode(),
        headers={"Content-Type": "application/json", "Authorization": key})
    with urllib.request.urlopen(req, timeout=12) as r:
        nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
    if not nodes:
        raise SystemExit(1)
    iid = nodes[0]["id"]
q2 = {"query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
      "variables": {"id": iid, "b": body}}
with urllib.request.urlopen(urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key}), timeout=12) as r:
    ok = (json.load(r).get("data") or {}).get("commentCreate", {}).get("success")
raise SystemExit(0 if ok else 1)
PY
}

if [[ ! -x "$_contract" ]]; then
  echo "fetching hermes-ral793-contract-install.sh from main" | tee -a "$LOG"
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh \
    -o "$DIR/hermes-ral793-contract-install.sh"
  chmod +x "$DIR/hermes-ral793-contract-install.sh"
  _contract="$DIR/hermes-ral793-contract-install.sh"
fi

if [[ ! -x "$_starve" ]]; then
  echo "fetching hermes-ral634-starvation-verify.sh from main" | tee -a "$LOG"
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh \
    -o "$DIR/hermes-ral634-starvation-verify.sh"
  chmod +x "$DIR/hermes-ral634-starvation-verify.sh"
  _starve="$DIR/hermes-ral634-starvation-verify.sh"
fi

_load_hermes_ssh_env || true
export HERMES_RAL793_LINEAR_ISSUE_ID="${LINEAR_ISSUE_ID}"
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "== Hermes dispatcher downstream @ $WHEN ==" | tee -a "$LOG"

echo "== Step 1: RAL-793 contract install ==" | tee -a "$LOG"
if ! bash "$_contract" --post-linear 2>&1 | tee -a "$LOG"; then
  echo "FAIL: contract install failed — not dispatching" | tee -a "$LOG"
  exit 1
fi

echo "" | tee -a "$LOG"
if [[ "$AUTO_DISPATCH" == "1" ]]; then
  echo "== Step 2: DISPATCH-NOW $LINEAR_TICKET (Linear interrupt) ==" | tee -a "$LOG"
  DISPATCH_BODY="DISPATCH-NOW $LINEAR_TICKET"
  if _post_linear_comment "$DISPATCH_BODY"; then
    echo "OK posted Linear interrupt comment: $DISPATCH_BODY" | tee -a "$LOG"
    _post_linear_comment "## Auto-dispatch @ $WHEN

Posted \`$DISPATCH_BODY\` after contract install/readback. Expect CLAIMED + \`evidence/RAL-793-inventory.md\` — not WORK-PACKET-DONE alone." || true
  else
    echo "WARN: could not post DISPATCH-NOW (missing LINEAR_API_KEY?) — post manually on $LINEAR_TICKET" | tee -a "$LOG"
  fi
else
  echo "SKIP Step 2: HERMES_AUTO_DISPATCH_RAL793=0 — post DISPATCH-NOW manually" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "== Step 3: RAL-634 starvation verify ==" | tee -a "$LOG"
bash "$_starve" --post-linear 2>&1 | tee -a "$LOG" || {
  echo "WARN: RAL-634 verify failed — see $LOG" | tee -a "$LOG"
}

echo "" | tee -a "$LOG"
echo "DONE downstream @ $WHEN" | tee -a "$LOG"
echo "  Expect inventory evidence on $LINEAR_TICKET (evidence/RAL-793-inventory.md)" | tee -a "$LOG"
echo "  Do NOT treat prior WORK-PACKET-DONE as objective closure" | tee -a "$LOG"
