#!/usr/bin/env bash
# hermes-ral634-starvation-verify.sh — read-only RAL-634 prove-out on live .11
#
# Verifies post-tip-main install includes:
#   - wip-park + miss-idle watchdog cron lines
#   - cos-linear-dispatcher-check.py present
#   - latest miss-idle-watchdog report exists
#   - dispatcher check does not silently pass on queue starvation signals
#
# Usage:
#   bash shared-scripts/hermes-ral634-starvation-verify.sh
#   bash shared-scripts/hermes-ral634-starvation-verify.sh --json --post-linear
set -euo pipefail

HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"
LINEAR_TICKET="${HERMES_RAL634_LINEAR_TICKET:-RAL-634}"
JSON_OUT=0
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
  f="$(mktemp /tmp/hermes-ral634-ssh.XXXXXX)"
  printf '%s\n' "$1" > "$f"
  chmod 600 "$f"
  echo "$f"
}

_load_host_pem() {
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY" && return 0
  [[ -s "$HOST_KEY_FILE" ]] && cat "$HOST_KEY_FILE" && return 0
  return 1
}

cleanup() { [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"; }
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    --post-linear) POST_LINEAR=1; shift ;;
    -h|--help) sed -n '1,18p' "$0"; exit 0 ;;
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

REMOTE_REPORT="$(_ssh_host "$HOST_TARGET" bash -s <<'REMOTE'
set -euo pipefail
MOLTBOT="/opt/moltbot"
SCRIPTS="$MOLTBOT/shared-scripts"
STATE="$MOLTBOT/data/cos-hermes/dispatcher"

wip_cron=0
miss_cron=0
crontab -l 2>/dev/null | grep -F 'hermes-dispatcher-wip-park.py' >/dev/null && wip_cron=1 || true
crontab -l 2>/dev/null | grep -F 'hermes-dispatcher-miss-idle-watchdog.sh' >/dev/null && miss_cron=1 || true

check_py=0
[[ -f "$SCRIPTS/cos-linear-dispatcher-check.py" ]] && check_py=1

watchdog_report="missing"
[[ -f "$STATE/miss-idle-watchdog-last.json" ]] && watchdog_report="$(cat "$STATE/miss-idle-watchdog-last.json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("kind"), d.get("heartbeat_status"), len(d.get("failures") or []))' 2>/dev/null || echo parse_error)"

check_json="{}"
check_rc=99
if [[ "$check_py" -eq 1 ]]; then
  if check_json="$(python3 "$SCRIPTS/cos-linear-dispatcher-check.py" --json 2>/dev/null || true)"; then
    check_rc=0
  else
    check_rc=$?
  fi
fi

queue_starved_hint=0
if python3 - <<'PY' 2>/dev/null
import json, os, sys
from pathlib import Path
state = Path("/opt/moltbot/data/cos-hermes/dispatcher")
runs = sorted(state.glob("runs/*"), key=lambda p: p.stat().st_mtime, reverse=True)
for run in runs[:5]:
    qp = run / "queue_poll.json"
    vf = run / "verifier.json"
    if not qp.exists() or not vf.exists():
        continue
    q = json.loads(qp.read_text())
    v = json.loads(vf.read_text())
    if (q.get("queue") == [] and q.get("label_poll_count", 0) > 0
        and len(q.get("skipped_processed") or []) > 0
        and v.get("status") == "pass"):
        print("starvation_silent_pass_detected")
        sys.exit(0)
sys.exit(1)
PY
then
  queue_starved_hint=1
fi

printf 'host=%s\n' "$(hostname)"
printf 'when=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'wip_cron=%s\n' "$wip_cron"
printf 'miss_cron=%s\n' "$miss_cron"
printf 'check_py=%s\n' "$check_py"
printf 'check_rc=%s\n' "$check_rc"
printf 'check_json=%s\n' "$check_json"
printf 'watchdog_report=%s\n' "$watchdog_report"
printf 'queue_starved_hint=%s\n' "$queue_starved_hint"
REMOTE
)"

declare -A REMOTE
while IFS= read -r line; do
  [[ "$line" == *"="* ]] || continue
  REMOTE["${line%%=*}"]="${line#*=}"
done <<< "$REMOTE_REPORT"

FAILS=()
PASS=()

[[ "${REMOTE[wip_cron]:-0}" == "1" ]] && PASS+=("wip-park cron installed") || FAILS+=("wip-park cron missing")
[[ "${REMOTE[miss_cron]:-0}" == "1" ]] && PASS+=("miss-idle watchdog cron installed") || FAILS+=("miss-idle watchdog cron missing")
[[ "${REMOTE[check_py]:-0}" == "1" ]] && PASS+=("cos-linear-dispatcher-check.py present") || FAILS+=("dispatcher check script missing")
[[ "${REMOTE[watchdog_report]:-}" != "missing" ]] && PASS+=("miss-idle-watchdog report present: ${REMOTE[watchdog_report]}") || FAILS+=("miss-idle-watchdog-last.json missing")
[[ "${REMOTE[queue_starved_hint]:-1}" == "0" ]] && PASS+=("no recent silent-pass starvation in last 5 runs") || FAILS+=("recent run shows empty queue + skipped_processed + verifier pass (RAL-634 regression)")

_post_linear() {
  local key="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
  [[ -n "$key" ]] || return 0
  python3 - "$key" "$LINEAR_TICKET" "$1" <<'PY' 2>/dev/null || true
import json, sys, urllib.request
key, ticket, body = sys.argv[1], sys.argv[2], sys.argv[3]
q1 = {"query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id}}}", "variables": {"q": ticket}}
req = urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q1).encode(),
    headers={"Content-Type": "application/json", "Authorization": key})
with urllib.request.urlopen(req, timeout=12) as r:
    nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
if not nodes: raise SystemExit(0)
iid = nodes[0]["id"]
q2 = {"query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
      "variables": {"id": iid, "b": body}}
urllib.request.urlopen(urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key}), timeout=12).read()
PY
}

if [[ "$JSON_OUT" -eq 1 ]]; then
  python3 - <<PY
import json
remote = {}
for line in """${REMOTE_REPORT}""".splitlines():
    if "=" in line:
        k,v=line.split("=",1); remote[k]=v
print(json.dumps({"when":"${WHEN}","host_target":"${HOST_TARGET}","remote":remote,
  "pass":$(printf '%s\n' "${PASS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
  "fail":$(printf '%s\n' "${FAILS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
  "ok":$( [[ ${#FAILS[@]} -eq 0 ]] && echo True || echo False )}, indent=2))
PY
else
  echo "== RAL-634 starvation verify @ $WHEN =="
  echo "host_ssh=$HOST_TARGET"
  echo "$REMOTE_REPORT"
  for i in "${PASS[@]}"; do echo "PASS: $i"; done
  for i in "${FAILS[@]}"; do echo "FAIL: $i"; done
  [[ ${#FAILS[@]} -eq 0 ]] && echo "RESULT: PASS" || echo "RESULT: FAIL"
fi

[[ "$POST_LINEAR" -eq 1 ]] && _post_linear "## RAL-634 verify @ $WHEN\n\n$(for i in \"${PASS[@]}\"; do echo \"- PASS: $i\"; done)\n$(for i in \"${FAILS[@]}\"; do echo \"- FAIL: $i\"; done)"

[[ ${#FAILS[@]} -gt 0 ]] && exit 1
exit 0
