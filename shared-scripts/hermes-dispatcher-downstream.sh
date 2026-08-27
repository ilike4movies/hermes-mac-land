#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — credentialed downstream gates after RAL-800/799
#
# Runs (in order):
#   0. RAL-793 run inspect (optional; when HERMES_RUN_ID set or HERMES_AUTO_INSPECT_RAL793=1)
#   1. RAL-793 contract install (--post-linear)
#   2. DISPATCH-NOW RAL-793 via Linear comment (default on; HERMES_AUTO_DISPATCH_RAL793=0 to skip)
#   3. RAL-634 starvation verify (--post-linear)
#
# Machine status: posts STARTED/DONE/FAILED to hermes-mac-land GitHub issue #1 when `gh` available.
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
AUTO_INSPECT="${HERMES_AUTO_INSPECT_RAL793:-}"
GH_STATUS_ISSUE="${HERMES_MAC_LAND_STATUS_ISSUE:-1}"
GH_STATUS_REPO="${HERMES_MAC_LAND_STATUS_REPO:-ilike4movies/hermes-mac-land}"
STARVE_RC=0

_contract="$DIR/hermes-ral793-contract-install.sh"
[[ -x "$_contract" ]] || _contract="$ROOT/shared-scripts/hermes-ral793-contract-install.sh"

_inspect="$DIR/hermes-ral793-run-inspect.sh"
[[ -x "$_inspect" ]] || _inspect="$ROOT/shared-scripts/hermes-ral793-run-inspect.sh"

_starve="$DIR/hermes-ral634-starvation-verify.sh"
[[ -x "$_starve" ]] || _starve="$ROOT/shared-scripts/hermes-ral634-starvation-verify.sh"

_load_hermes_ssh_env() {
  local f key val
  for f in "${HOME}/.hermes/.env" /opt/moltbot/config/secrets.env "${HOME}/.openclaw/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*)
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

_post_github_status() {
  local body="$1"
  command -v gh >/dev/null 2>&1 || return 0
  gh issue comment "$GH_STATUS_ISSUE" --repo "$GH_STATUS_REPO" --body "$body" >/dev/null 2>&1 || true
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

_fetch_script() {
  local name="$1" dest="$2"
  echo "fetching $name from main" | tee -a "$LOG"
  curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/$name" \
    -o "$dest"
  chmod +x "$dest"
}

if [[ ! -x "$_contract" ]]; then
  _fetch_script "hermes-ral793-contract-install.sh" "$DIR/hermes-ral793-contract-install.sh"
  _contract="$DIR/hermes-ral793-contract-install.sh"
fi

if [[ ! -x "$_inspect" ]]; then
  _fetch_script "hermes-ral793-run-inspect.sh" "$DIR/hermes-ral793-run-inspect.sh"
  _inspect="$DIR/hermes-ral793-run-inspect.sh"
fi

if [[ ! -x "$_starve" ]]; then
  _fetch_script "hermes-ral634-starvation-verify.sh" "$DIR/hermes-ral634-starvation-verify.sh"
  _starve="$DIR/hermes-ral634-starvation-verify.sh"
fi

_load_hermes_ssh_env || true
export HERMES_RAL793_LINEAR_ISSUE_ID="${LINEAR_ISSUE_ID}"

if [[ -z "$AUTO_INSPECT" ]]; then
  if [[ -n "${HERMES_RUN_ID:-}" ]]; then
    AUTO_INSPECT=1
  else
    AUTO_INSPECT=0
  fi
fi

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"
USER_NAME="$(whoami 2>/dev/null || echo unknown)"

_post_github_status "## Downstream STARTED @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
chain: inspect(auto=$AUTO_INSPECT) → contract install → DISPATCH-NOW (auto=$AUTO_DISPATCH) → RAL-634 verify
log: \`$LOG\`"

echo "== Hermes dispatcher downstream @ $WHEN ==" | tee -a "$LOG"

if [[ "$AUTO_INSPECT" == "1" ]]; then
  echo "== Step 0: RAL-793 run inspect (read-only) ==" | tee -a "$LOG"
  _inspect_args=(--post-linear)
  [[ -n "${HERMES_RUN_ID:-}" ]] && _inspect_args=(--run "$HERMES_RUN_ID" --post-linear)
  if bash "$_inspect" "${_inspect_args[@]}" 2>&1 | tee -a "$LOG"; then
    echo "OK run inspect" | tee -a "$LOG"
  else
    echo "WARN: run inspect failed (continuing downstream)" | tee -a "$LOG"
  fi
  echo "" | tee -a "$LOG"
fi

echo "== Step 1: RAL-793 contract install ==" | tee -a "$LOG"
if ! bash "$_contract" --post-linear 2>&1 | tee -a "$LOG"; then
  echo "FAIL: contract install failed — not dispatching" | tee -a "$LOG"
  _post_github_status "## Downstream FAILED @ $WHEN

step=contract-install
host=\`$HOST\` user=\`$USER_NAME\`
See log: \`$LOG\`"
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
if bash "$_starve" --post-linear 2>&1 | tee -a "$LOG"; then
  STARVE_RC=0
else
  STARVE_RC=$?
  echo "WARN: RAL-634 verify failed — see $LOG" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "DONE downstream @ $WHEN" | tee -a "$LOG"
echo "  Expect inventory evidence on $LINEAR_TICKET (evidence/RAL-793-inventory.md)" | tee -a "$LOG"
echo "  Do NOT treat prior WORK-PACKET-DONE as objective closure" | tee -a "$LOG"

if [[ "$STARVE_RC" -eq 0 ]]; then
  _post_github_status "## Downstream DONE @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
contract install: OK
DISPATCH-NOW: auto=$AUTO_DISPATCH
RAL-634 verify: PASS

Watch Linear for inventory evidence on $LINEAR_TICKET — not WORK-PACKET-DONE alone."
else
  _post_github_status "## Downstream PARTIAL @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
contract install: OK
DISPATCH-NOW: auto=$AUTO_DISPATCH
RAL-634 verify: FAIL (rc=$STARVE_RC)

See log: \`$LOG\`"
  exit "$STARVE_RC"
fi
