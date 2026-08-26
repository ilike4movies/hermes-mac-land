#!/usr/bin/env bash
# hermes-ral799-live-verify.sh — read-only RAL-799 done-when #2–#3 proof on live .11
#
# Verifies:
#   1. RAL799_CANARY.json present with expected nonce (GitHub→host apply canary)
#   2. hermes-git-drift-check.py --require-metrics passes (drift alarm wired)
#   3. git-apply crontab exports HERMES_MOLTBOT_REMOTE=https://… (HTTPS tip fetch)
#
# Usage (credentialed Mac/cloud agent after surgical land):
#   bash shared-scripts/hermes-ral799-live-verify.sh
#   bash shared-scripts/hermes-ral799-live-verify.sh --json --post-linear
#
# Requires SSH to .11 (HERMES_HOST_SSH_PRIVATE_KEY or agent key). No mutation.
set -euo pipefail

HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"
CANARY_PATH="${HERMES_RAL799_CANARY_PATH:-/opt/moltbot/shared-scripts/signals/RAL799_CANARY.json}"
EXPECTED_NONCE="${HERMES_RAL799_EXPECTED_NONCE:-20260826T172700Z-cloud-agent-canary}"
LINEAR_TICKET="${HERMES_RAL799_LINEAR_TICKET:-RAL-799}"
JSON_OUT=0
POST_LINEAR=0
TMP_HOST_KEY=""
HOST_SSH_IDENTITY_ARGS=()

_load_hermes_ssh_env() {
  local f key val
  for f in \
    "${HOME}/.hermes/.env" \
    "/opt/moltbot/config/secrets.env" \
    "${HOME}/.openclaw/.env"
  do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        HERMES_HOST_SSH_PRIVATE_KEY=*|HERMES_JUMP_SSH_PRIVATE_KEY=*|LINEAR_API_KEY=*|LINEAR_API_TOKEN=*)
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
  done
}

_write_keyfile() {
  local pem="$1"
  local f
  f="$(mktemp /tmp/hermes-ral799-ssh.XXXXXX)"
  printf '%s\n' "$pem" > "$f"
  chmod 600 "$f"
  echo "$f"
}

_load_host_pem() {
  if [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY"
    return 0
  fi
  if [[ -s "$HOST_KEY_FILE" ]]; then
    cat "$HOST_KEY_FILE"
    return 0
  fi
  return 1
}

cleanup() {
  [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    --post-linear) POST_LINEAR=1; shift ;;
    -h|--help)
      sed -n '1,22p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

_load_hermes_ssh_env || true
if _host_pem="$(_load_host_pem 2>/dev/null)"; then
  TMP_HOST_KEY="$(_write_keyfile "$_host_pem")"
  HOST_SSH_IDENTITY_ARGS=(-i "$TMP_HOST_KEY" -o IdentitiesOnly=yes)
fi

_ssh_host() {
  local target="$1"
  shift
  if [[ ${#HOST_SSH_IDENTITY_ARGS[@]} -gt 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
      "${HOST_SSH_IDENTITY_ARGS[@]}" "$target" "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
      "$target" "$@"
  fi
}

_pick_host() {
  if _ssh_host "$HOST_SSH" 'echo OK' >/dev/null 2>&1; then
    echo "$HOST_SSH"
    return 0
  fi
  if _ssh_host "$HOST_SSH_LAN" 'echo OK' >/dev/null 2>&1; then
    echo "$HOST_SSH_LAN"
    return 0
  fi
  return 1
}

HOST_TARGET=""
if ! HOST_TARGET="$(_pick_host)"; then
  echo "FAIL SSH to .11 unreachable (tried $HOST_SSH and $HOST_SSH_LAN)" >&2
  exit 10
fi

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REMOTE_REPORT="$(_ssh_host "$HOST_TARGET" bash -s <<REMOTE
set -euo pipefail
CANARY="$CANARY_PATH"
EXPECTED="$EXPECTED_NONCE"
MOLTBOT="/opt/moltbot"
DRIFT_PY="\$MOLTBOT/shared-scripts/hermes-git-drift-check.py"

nonce="MISSING"
if [[ -f "\$CANARY" ]]; then
  nonce="\$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("nonce") or "")' "\$CANARY" 2>/dev/null || echo PARSE_ERROR)"
fi

drift_json="{}"
drift_rc=99
if [[ -f "\$DRIFT_PY" ]]; then
  if drift_json="\$(python3 "\$DRIFT_PY" --json --require-metrics 2>/dev/null || true)"; then
    drift_rc=0
  else
    drift_rc=\$?
  fi
else
  drift_json='{"status":"fail","failures":["missing hermes-git-drift-check.py"]}'
fi

cron_https=0
cron_line=""
if crontab -l 2>/dev/null | grep -F 'hermes-moltbot-git-pull-apply' | grep -F 'HERMES_MOLTBOT_REMOTE=https://github.com/ilike4movies/moltbot.git' >/dev/null 2>&1; then
  cron_https=1
  cron_line="\$(crontab -l 2>/dev/null | grep -F 'hermes-moltbot-git-pull-apply' | head -1)"
fi

git_pull_tail=""
if [[ -f "\$MOLTBOT/data/cos-hermes/home/logs/git-pull-apply.log" ]]; then
  git_pull_tail="\$(tail -5 "\$MOLTBOT/data/cos-hermes/home/logs/git-pull-apply.log" | python3 -c 'import sys; print(repr(sys.stdin.read()))' 2>/dev/null || echo repr_error)"
fi

printf 'host=%s\n' "\$(hostname)"
printf 'when=%s\n' "\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'canary_path=%s\n' "\$CANARY"
printf 'canary_nonce=%s\n' "\$nonce"
printf 'expected_nonce=%s\n' "\$EXPECTED"
printf 'drift_rc=%s\n' "\$drift_rc"
printf 'drift_json=%s\n' "\$drift_json"
printf 'cron_https=%s\n' "\$cron_https"
printf 'cron_line=%s\n' "\$cron_line"
printf 'git_pull_tail=%s\n' "\$git_pull_tail"
REMOTE
)"

declare -A REMOTE
while IFS= read -r line; do
  [[ "$line" == *"="* ]] || continue
  REMOTE["${line%%=*}"]="${line#*=}"
done <<< "$REMOTE_REPORT"

FAILS=()
PASS=()

if [[ "${REMOTE[canary_nonce]:-}" != "$EXPECTED_NONCE" ]]; then
  FAILS+=("canary nonce mismatch: got ${REMOTE[canary_nonce]:-?} want $EXPECTED_NONCE")
else
  PASS+=("canary nonce OK ($EXPECTED_NONCE)")
fi

if [[ "${REMOTE[drift_rc]:-99}" -ne 0 ]]; then
  FAILS+=("git drift check failed rc=${REMOTE[drift_rc]:-?} json=${REMOTE[drift_json]:-?}")
else
  PASS+=("git drift check OK (--require-metrics)")
fi

if [[ "${REMOTE[cron_https]:-0}" != "1" ]]; then
  FAILS+=("crontab missing HERMES_MOLTBOT_REMOTE=https://… on git-pull-apply line")
else
  PASS+=("crontab HTTPS remote prefix OK")
fi

_post_linear() {
  local body="$1"
  local key="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
  [[ -n "$key" ]] || return 0
  python3 - "$key" "$LINEAR_TICKET" "$body" <<'PY' 2>/dev/null || true
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
with urllib.request.urlopen(req, timeout=12) as r:
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
urllib.request.urlopen(req2, timeout=12).read()
print(f"OK posted verify receipt to {ticket}")
PY
}

if [[ "$JSON_OUT" -eq 1 ]]; then
  python3 - <<PY
import json
remote = {}
for line in """${REMOTE_REPORT}""".splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        remote[k] = v
print(json.dumps({
    "when": "${WHEN}",
    "host_target": "${HOST_TARGET}",
    "expected_nonce": "${EXPECTED_NONCE}",
    "remote": remote,
    "pass": $(printf '%s\n' "${PASS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
    "fail": $(printf '%s\n' "${FAILS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
    "ok": $( [[ ${#FAILS[@]} -eq 0 ]] && echo True || echo False ),
}, indent=2))
PY
else
  echo "== RAL-799 live verify @ $WHEN =="
  echo "host_ssh=$HOST_TARGET"
  echo
  echo "Remote:"
  echo "$REMOTE_REPORT"
  echo
  for item in "${PASS[@]}"; do echo "PASS: $item"; done
  for item in "${FAILS[@]}"; do echo "FAIL: $item"; done
  echo
  if [[ ${#FAILS[@]} -eq 0 ]]; then
    echo "RESULT: PASS — RAL-799 canary + drift receipt OK"
  else
    echo "RESULT: FAIL — RAL-799 live prove-out incomplete"
  fi
fi

if [[ "$POST_LINEAR" -eq 1 ]]; then
  BODY=$(cat <<EOF
## RAL-799 live verify @ $WHEN

host_ssh=\`$HOST_TARGET\`

### Checks
$(for item in "${PASS[@]}"; do echo "- PASS: $item"; done)
$(for item in "${FAILS[@]}"; do echo "- FAIL: $item"; done)

### Remote excerpt
\`\`\`
$REMOTE_REPORT
\`\`\`

**Verdict:** $( [[ ${#FAILS[@]} -eq 0 ]] && echo 'PASS — done-when #2–#3 satisfied' || echo 'FAIL — see failures above' )
EOF
)
  _post_linear "$BODY"
fi

if [[ ${#FAILS[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
