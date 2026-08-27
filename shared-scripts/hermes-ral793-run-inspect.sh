#!/usr/bin/env bash
# hermes-ral793-run-inspect.sh — read-only inspect of a dispatcher run on live .11
#
# Use when RAL-793 is CLAIMED but Linear is silent (possible stall). Posts summary
# to RAL-793 with --post-linear. Does NOT dispatch or modify host state.
#
# Usage:
#   bash shared-scripts/hermes-ral793-run-inspect.sh
#   bash shared-scripts/hermes-ral793-run-inspect.sh --run 20260826T232521106484Z-2954673
#   bash shared-scripts/hermes-ral793-run-inspect.sh --post-linear
#   HERMES_RUN_ID=20260826T232521106484Z-2954673 curl -fsSL .../hermes-ral793-run-inspect.sh | bash -s -- --post-linear
set -euo pipefail

HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"
LINEAR_TICKET="${HERMES_RAL793_LINEAR_TICKET:-RAL-793}"
LINEAR_ISSUE_ID="${HERMES_RAL793_LINEAR_ISSUE_ID:-963472c8-cc84-426a-9ed6-79e08566353a}"
RUN_ID="${HERMES_RUN_ID:-}"
POST_LINEAR=0
TMP_HOST_KEY=""
HOST_SSH_IDENTITY_ARGS=()

_load_hermes_ssh_env() {
  local f key val
  for f in "${HOME}/.hermes/.env" /opt/moltbot/config/secrets.env "${HOME}/.openclaw/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        HERMES_HOST_SSH_PRIVATE_KEY=*|LINEAR_API_KEY=*|LINEAR_API_TOKEN=*)
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

_write_keyfile() {
  local f
  f="$(mktemp /tmp/hermes-ral793-inspect-ssh.XXXXXX)"
  printf '%s\n' "$1" > "$f"
  chmod 600 "$f"
  echo "$f"
}

_load_host_pem() {
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY" && return 0
  [[ -s "$HOST_KEY_FILE" ]] && cat "$HOST_KEY_FILE" && return 0
  return 1
}

_post_linear() {
  local body="$1"
  local key="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
  [[ -n "$key" ]] || return 0
  python3 - "$key" "$LINEAR_TICKET" "${LINEAR_ISSUE_ID:-}" "$body" <<'PY' 2>/dev/null || true
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
        raise SystemExit(0)
    iid = nodes[0]["id"]
q2 = {"query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
      "variables": {"id": iid, "b": body}}
with urllib.request.urlopen(urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key}), timeout=12) as r:
    ok = (json.load(r).get("data") or {}).get("commentCreate", {}).get("success")
raise SystemExit(0 if ok else 1)
PY
}

cleanup() { [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"; }
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN_ID="${2:-}"; shift 2 ;;
    --post-linear) POST_LINEAR=1; shift ;;
    -h|--help)
      sed -n '1,12p' "$0"
      echo "  HERMES_RUN_ID  optional run directory name under dispatcher/runs/"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

_load_hermes_ssh_env || true
if _host_pem="$(_load_host_pem 2>/dev/null)"; then
  TMP_HOST_KEY="$(_write_keyfile "$_host_pem")"
  HOST_SSH_IDENTITY_ARGS=(-i "$TMP_HOST_KEY" -o IdentitiesOnly=yes)
fi

_ssh_host() {
  local target="$1"; shift
  if [[ ${#HOST_SSH_IDENTITY_ARGS[@]} -gt 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new \
      "${HOST_SSH_IDENTITY_ARGS[@]}" "$target" "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "$target" "$@"
  fi
}

_pick_host() {
  _ssh_host "$HOST_SSH" 'echo OK' >/dev/null 2>&1 && { echo "$HOST_SSH"; return 0; }
  _ssh_host "$HOST_SSH_LAN" 'echo OK' >/dev/null 2>&1 && { echo "$HOST_SSH_LAN"; return 0; }
  return 1
}

HOST_TARGET="$(_pick_host)" || { echo "FAIL SSH to .11" >&2; exit 10; }
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

REMOTE_OUT="$(_ssh_host "$HOST_TARGET" bash -s -- "$RUN_ID" <<'REMOTE'
set -euo pipefail
RUN_FILTER="${1:-}"
DISPATCHER="/opt/moltbot/data/cos-hermes/dispatcher"
RUNS="$DISPATCHER/runs"
CANARY_ROOT="/opt/moltbot/data/cos-hermes/canaries/ral793-inventory"
REGISTRY="/opt/moltbot/data/cos-hermes/execution-contract-registry.json"

pick_run() {
  local rid="$1"
  if [[ -n "$rid" ]]; then
    echo "$rid"
    return 0
  fi
  if [[ -f "$DISPATCHER/current-ticket.json" ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
p = Path("/opt/moltbot/data/cos-hermes/dispatcher/current-ticket.json")
try:
    d = json.loads(p.read_text())
    run = (d.get("run_id") or d.get("run") or "").strip()
    if run:
        print(run)
except Exception:
    pass
PY
    return 0
  fi
  ls -1dt "$RUNS"/*/ 2>/dev/null | head -1 | xargs -I{} basename {}
}

RUN_ID="$(pick_run "$RUN_FILTER" | head -1 | tr -d '\n')"
RUN_DIR="$RUNS/$RUN_ID"

echo "=== hermes-ral793-run-inspect @ $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "run_id=$RUN_ID"
echo "run_dir=$RUN_DIR"

if [[ ! -d "$RUN_DIR" ]]; then
  echo "status=MISSING_RUN_DIR"
  exit 3
fi

for f in result.json verifier.json queue_poll.json heartbeat.json; do
  if [[ -f "$RUN_DIR/$f" ]]; then
    echo "--- $f ---"
    head -c 4000 "$RUN_DIR/$f"
    echo
  else
    echo "--- $f --- MISSING"
  fi
done

for f in report.md prompt.md; do
  if [[ -f "$RUN_DIR/$f" ]]; then
    echo "--- $f (head) ---"
    head -n 40 "$RUN_DIR/$f"
    echo
  else
    echo "--- $f --- MISSING"
  fi
done

if [[ -f "$DISPATCHER/heartbeat.json" ]]; then
  echo "--- dispatcher/heartbeat.json ---"
  head -c 2000 "$DISPATCHER/heartbeat.json"
  echo
fi

if [[ -f "$CANARY_ROOT/evidence/RAL-793-inventory.md" ]]; then
  echo "--- evidence/RAL-793-inventory.md (head) ---"
  head -n 30 "$CANARY_ROOT/evidence/RAL-793-inventory.md"
  echo
else
  echo "--- evidence/RAL-793-inventory.md --- MISSING"
fi

if [[ -f "$REGISTRY" ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
p = Path("/opt/moltbot/data/cos-hermes/execution-contract-registry.json")
d = json.loads(p.read_text())
c = (d.get("contracts") or {}).get("RAL-793")
print("contract_RAL-793_present", bool(c))
if c:
    print("execution_mode", c.get("execution_mode"))
PY
fi

if [[ -d "$RUN_DIR" ]]; then
  echo "run_dir_mtime_utc=$(date -u -r "$RUN_DIR" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || stat -c %y "$RUN_DIR" 2>/dev/null || echo unknown)"
  find "$RUN_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -3 | while read -r ts path; do
    echo "newest_file=$path"
  done
fi
REMOTE
)"

echo "$REMOTE_OUT"

if [[ "$POST_LINEAR" -eq 1 ]]; then
  RUN_LINE="$(printf '%s\n' "$REMOTE_OUT" | awk -F= '/^run_id=/{print $2; exit}')"
  STATUS_LINE="$(printf '%s\n' "$REMOTE_OUT" | awk -F= '/^status=/{print $2; exit}')"
  INVENTORY="$(printf '%s\n' "$REMOTE_OUT" | grep -q 'evidence/RAL-793-inventory.md --- MISSING' && echo MISSING || echo present)"
  CONTRACT="$(printf '%s\n' "$REMOTE_OUT" | awk -F' ' '/contract_RAL-793_present/{print $2; exit}')"
  BODY="## Run inspect @ $WHEN

host=\`$HOST_TARGET\` run=\`${RUN_LINE:-unknown}\`

\`\`\`
$(printf '%s\n' "$REMOTE_OUT" | head -n 80)
\`\`\`

| Check | Result |
|-------|--------|
| Run dir | ${STATUS_LINE:-OK} |
| Inventory file | **$INVENTORY** |
| Contract RAL-793 pinned | **${CONTRACT:-unknown}** |

Read-only inspect — no dispatch performed."
  _post_linear "$BODY"
fi

echo "OK inspect complete @ $WHEN"
