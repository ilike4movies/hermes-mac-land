#!/usr/bin/env bash
# hermes-moltbot-stack-apply-via-ssh.sh — governed moltbot stack-apply on live .11
#
# Copies origin/main governed stack into /opt/moltbot without full surgical land.
# Downstream chain uses this when HERMES_AUTO_SURGICAL_LAND=0 but verify needs #103 artifacts.
#
# Usage:
#   bash shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh
#   bash shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh --dry-run --post-linear
set -euo pipefail

HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"
LINEAR_TICKET="${HERMES_RAL634_LINEAR_TICKET:-RAL-634}"
LINEAR_ISSUE_ID="${HERMES_RAL634_LINEAR_ISSUE_ID:-1b5a7e86-1d14-456f-b0d1-39a02df243c2}"
REPO="${HERMES_MOLTBOT_REPO:-/opt/moltbot}"
DRY_RUN=0
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
  f="$(mktemp /tmp/hermes-stack-apply-ssh.XXXXXX)"
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
urllib.request.urlopen(urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key}), timeout=12).read()
PY
}

cleanup() { [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"; }
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --post-linear) POST_LINEAR=1; shift ;;
    -h|--help) sed -n '1,14p' "$0"; exit 0 ;;
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

_ssh_fail_diag() {
  echo "FAIL SSH to .11 — diagnostic:" >&2
  echo "  caller: $(hostname 2>/dev/null)/$(whoami 2>/dev/null)" >&2
  echo "  targets: $HOST_SSH, $HOST_SSH_LAN" >&2
  if [[ ${#HOST_SSH_IDENTITY_ARGS[@]} -gt 0 ]]; then
    echo "  key: loaded" >&2
  else
    echo "  key: not loaded — set HERMES_HOST_SSH_PRIVATE_KEY" >&2
  fi
}

HOST_TARGET="$(_pick_host)" || { _ssh_fail_diag; exit 10; }
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would run governed stack-apply on $HOST_TARGET:$REPO"
  exit 0
fi

echo "== governed stack-apply via $HOST_TARGET @ $WHEN =="

REMOTE_OUT="$(_ssh_host "$HOST_TARGET" bash -s -- "$REPO" <<'REMOTE'
set -euo pipefail
REPO="${1:-/opt/moltbot}"
STACK="$REPO/shared-scripts/hermes-moltbot-stack-apply.sh"
if [[ ! -x "$STACK" ]]; then
  echo "FAIL missing stack-apply script: $STACK" >&2
  exit 12
fi
cd "$REPO" || exit 13
bash "$STACK" 2>&1
META="$REPO/data/cos-hermes/dispatcher/stack-apply-last.json"
if [[ -f "$META" ]]; then
  echo "--- stack-apply-last.json ---"
  cat "$META"
fi
TRANSITION="$REPO/shared-scripts/hermes-dispatcher-watchdog-transition.py"
if [[ -f "$TRANSITION" ]]; then
  echo "transition_py=present"
else
  echo "transition_py=missing"
  exit 14
fi
REMOTE
)"

echo "$REMOTE_OUT"

MIRROR_SHA="$(printf '%s\n' "$REMOTE_OUT" | python3 -c 'import json,sys
for line in sys.stdin:
    line=line.strip()
    if line.startswith("{"):
        try:
            d=json.loads(line)
            print(d.get("mirror_sha","")[:12])
            break
        except Exception:
            pass
' 2>/dev/null || true)"

if ! printf '%s\n' "$REMOTE_OUT" | grep -q 'transition_py=present'; then
  echo "FAIL: post-apply transition helper missing on .11" >&2
  exit 14
fi

echo "OK stack-apply complete mirror_sha=${MIRROR_SHA:-unknown}"

if [[ "$POST_LINEAR" -eq 1 ]]; then
  _post_linear "## Governed stack-apply @ $WHEN

host=\`$HOST_TARGET\`
mirror_sha_prefix=\`${MIRROR_SHA:-unknown}\`

Post-#103 transition helper present on live .11."
fi
