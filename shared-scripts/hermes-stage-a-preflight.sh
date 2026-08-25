#!/usr/bin/env bash
# hermes-stage-a-preflight.sh — read-only Stage A gate check on live .11
#
# Verifies healthy preimage, timer, canary fixture, and pins hermes-agent-cos
# cos-local @ 5bcb257e (PR #86 WAL finalizer) before bounded Stage A activation.
#
# Usage (after surgical land or from credentialed cloud/Mac agent):
#   bash shared-scripts/hermes-stage-a-preflight.sh
#   bash shared-scripts/hermes-stage-a-preflight.sh --json
#
# Requires SSH to .11 (HERMES_HOST_SSH_PRIVATE_KEY or agent key).
# No live mutation. Exit 0 = preflight PASS; non-zero = blocked.
set -euo pipefail

COS_LOCAL_SHA="${HERMES_COS_LOCAL_SHA:-5bcb257e}"
COS_OWNER_REPO="${HERMES_COS_OWNER_REPO:-ilike4movies/hermes-agent-cos}"
COS_BRANCH="${HERMES_COS_BRANCH:-cos-local}"
HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"
CANARY_SUBJECT="${HERMES_RAL820_SUBJECT:-/opt/moltbot/data/cos-hermes/canaries/ral798-subject/subject.txt}"
JSON_OUT=0
TMP_HOST_KEY=""
HOST_SSH_IDENTITY_ARGS=()

# Healthy preimage from 20:49Z rollback (must match before Stage A install).
DISPATCHER_PREIMAGE="2cb904b832f08e3c1ca8cd151680d8819e08938ee89bbdafa3491f59f93049e3"
ORCHESTRATOR_PREIMAGE="9d12317659144ebc0243fae9e5abb834def081b7de5d1dee574bb858750aab4e"
REGISTRY_PREIMAGE="1c8812413c7fcdc23220601a7a81c004208c4dacfa86f4b94bb32fde7b71c76b"

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
        HERMES_HOST_SSH_PRIVATE_KEY=*|HERMES_JUMP_SSH_PRIVATE_KEY=*)
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
  f="$(mktemp /tmp/hermes-stagea-ssh.XXXXXX)"
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
    -h|--help)
      sed -n '1,20p' "$0"
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

_check_cos_source() {
  local extract inner guard_init
  local extract_dir="/tmp/hermes-cos-stagea-preflight-$$"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  if ! command -v gh >/dev/null 2>&1; then
    echo "WARN: gh missing — skipping cos-local source pin check"
    rm -rf "$extract_dir"
    return 0
  fi

  if ! gh api "repos/${COS_OWNER_REPO}/commits/${COS_BRANCH}" \
      --jq ".sha" 2>/dev/null | grep -qi "^${COS_LOCAL_SHA}"; then
    local tip
    tip="$(gh api "repos/${COS_OWNER_REPO}/commits/${COS_BRANCH}" --jq .sha 2>/dev/null || echo unknown)"
    echo "FAIL cos-local tip mismatch: need ${COS_LOCAL_SHA}* got ${tip}"
    rm -rf "$extract_dir"
    return 1
  fi

  if ! gh api "repos/${COS_OWNER_REPO}/tarball/${COS_BRANCH}" | tar -xz -C "$extract_dir" 2>/dev/null; then
    echo "FAIL could not fetch ${COS_OWNER_REPO}@${COS_BRANCH} tarball"
    rm -rf "$extract_dir"
    return 1
  fi

  inner="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -1)"
  guard_init="${inner}/ops/ral733-budget-guard/__init__.py"
  if [[ ! -f "$guard_init" ]]; then
    echo "FAIL missing ops/ral733-budget-guard/__init__.py in staged source"
    rm -rf "$extract_dir"
    return 1
  fi
  if ! grep -q 'finalize_worker_session_usage' "$guard_init"; then
    echo "FAIL PR #86 WAL finalizer missing in cos-local@${COS_LOCAL_SHA}"
    rm -rf "$extract_dir"
    return 1
  fi
  if ! grep -q 'reportback_verified' "$guard_init"; then
    echo "FAIL reportback_verified path missing in cos-local@${COS_LOCAL_SHA}"
    rm -rf "$extract_dir"
    return 1
  fi

  rm -rf "$extract_dir"
  echo "OK cos-local@${COS_LOCAL_SHA} source pin + WAL finalizer present"
  return 0
}

HOST_TARGET=""
if ! HOST_TARGET="$(_pick_host)"; then
  echo "FAIL SSH to .11 unreachable (tried $HOST_SSH and $HOST_SSH_LAN)" >&2
  exit 10
fi

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REMOTE_REPORT="$(_ssh_host "$HOST_TARGET" bash -s <<'REMOTE'
set -euo pipefail
DISPATCHER="/opt/moltbot/shared-scripts/cos-linear-dispatcher.py"
ORCH="/opt/moltbot/shared-scripts/cos-hermes-orchestrator.sh"
REGISTRY="/opt/moltbot/shared-scripts/cos-hermes-execution-registry.json"
RAL798_MARKER="/opt/moltbot/shared-scripts/RAL798_ENABLED"
CANARY_SUBJECT="/opt/moltbot/data/cos-hermes/canaries/ral798-subject/subject.txt"

_sha() {
  if [[ -f "$1" ]]; then
    sha256sum "$1" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "MISSING"
  fi
}

timer_state="$(systemctl --user is-active cos-hermes-orchestrator.timer 2>/dev/null || echo inactive)"
timer_enabled="$(systemctl --user is-enabled cos-hermes-orchestrator.timer 2>/dev/null || echo disabled)"
gw_state="$(systemctl --user is-active hermes-gateway.service 2>/dev/null || echo inactive)"
subject="$(cat "$CANARY_SUBJECT" 2>/dev/null || echo MISSING)"
ral798_marker="absent"
[[ -f "$RAL798_MARKER" ]] && ral798_marker="present"

printf 'host=%s\n' "$(hostname)"
printf 'when=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'dispatcher_sha=%s\n' "$(_sha "$DISPATCHER")"
printf 'orchestrator_sha=%s\n' "$(_sha "$ORCH")"
printf 'registry_sha=%s\n' "$(_sha "$REGISTRY")"
printf 'timer_active=%s\n' "$timer_state"
printf 'timer_enabled=%s\n' "$timer_enabled"
printf 'gateway_active=%s\n' "$gw_state"
printf 'ral798_enabled=%s\n' "$ral798_marker"
printf 'subject_txt=%s\n' "$(printf '%s' "$subject" | python3 -c 'import sys; print(repr(sys.stdin.read()))' 2>/dev/null || echo repr_error)"
REMOTE
)"

declare -A REMOTE
while IFS= read -r line; do
  [[ "$line" == *"="* ]] || continue
  REMOTE["${line%%=*}"]="${line#*=}"
done <<< "$REMOTE_REPORT"

FAILS=()
PASS=()

if [[ "${REMOTE[dispatcher_sha]:-}" != "$DISPATCHER_PREIMAGE" ]]; then
  FAILS+=("dispatcher preimage mismatch: got ${REMOTE[dispatcher_sha]:-?} want $DISPATCHER_PREIMAGE")
else
  PASS+=("dispatcher preimage OK")
fi
if [[ "${REMOTE[orchestrator_sha]:-}" != "$ORCHESTRATOR_PREIMAGE" ]]; then
  FAILS+=("orchestrator preimage mismatch: got ${REMOTE[orchestrator_sha]:-?} want $ORCHESTRATOR_PREIMAGE")
else
  PASS+=("orchestrator preimage OK")
fi
if [[ "${REMOTE[registry_sha]:-}" != "$REGISTRY_PREIMAGE" ]]; then
  FAILS+=("registry preimage mismatch: got ${REMOTE[registry_sha]:-?} want $REGISTRY_PREIMAGE")
else
  PASS+=("registry preimage OK")
fi
if [[ "${REMOTE[timer_active]:-}" != "active" || "${REMOTE[timer_enabled]:-}" != "enabled" ]]; then
  FAILS+=("timer not active+enabled: active=${REMOTE[timer_active]:-?} enabled=${REMOTE[timer_enabled]:-?}")
else
  PASS+=("timer active+enabled")
fi
if [[ "${REMOTE[ral798_enabled]:-}" != "absent" ]]; then
  FAILS+=("RAL798_ENABLED must be absent before Stage A (got ${REMOTE[ral798_enabled]:-?})")
else
  PASS+=("RAL798_ENABLED absent")
fi
if [[ "${REMOTE[subject_txt]:-}" != "'pending\\n'" ]]; then
  FAILS+=("subject.txt must be pending\\n (got ${REMOTE[subject_txt]:-?})")
else
  PASS+=("subject.txt pending")
fi

if ! _cos_msg="$(_check_cos_source)"; then
  FAILS+=("$_cos_msg")
else
  PASS+=("$_cos_msg")
fi

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
    "cos_local_sha": "${COS_LOCAL_SHA}",
    "remote": remote,
    "pass": $(printf '%s\n' "${PASS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
    "fail": $(printf '%s\n' "${FAILS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
    "ok": $( [[ ${#FAILS[@]} -eq 0 ]] && echo True || echo False ),
}, indent=2))
PY
else
  echo "== Stage A preflight (read-only) @ $WHEN =="
  echo "host_ssh=$HOST_TARGET"
  echo "cos_local_pin=${COS_LOCAL_SHA} (${COS_OWNER_REPO}@${COS_BRANCH})"
  echo
  echo "Remote:"
  echo "$REMOTE_REPORT"
  echo
  for item in "${PASS[@]}"; do echo "PASS: $item"; done
  for item in "${FAILS[@]}"; do echo "FAIL: $item"; done
  echo
  if [[ ${#FAILS[@]} -eq 0 ]]; then
    echo "RESULT: PASS — Stage A activation may proceed per deployment-packet.md"
    echo "Token: APPROVE-RJS-LIVE-BUNDLE-1 (after Ralph review)"
  else
    echo "RESULT: BLOCKED — fix failures before Stage A"
  fi
fi

if [[ ${#FAILS[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
