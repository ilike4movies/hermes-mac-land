#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — credentialed downstream gates after RAL-800/799
#
# Runs (in order):
#   0. RAL-793 run inspect (optional; when HERMES_RUN_ID set or HERMES_AUTO_INSPECT_RAL793=1)
#   1. RAL-793 contract install (--post-linear)
#   2. governed stack-apply (moltbot main → .11; HERMES_AUTO_STACK_APPLY=0 to skip)
#   3. DISPATCH-NOW RAL-793 via Linear comment (default on; HERMES_AUTO_DISPATCH_RAL793=0 to skip)
#      stall_recovery=1 → two DISPATCH-NOW passes (~90s) to clear SLA-stale CLAIM then reopen
#      FAIL-CLOSED if AUTO_DISPATCH=1 and no DISPATCH-NOW post succeeds (needs LINEAR_API_KEY)
#   4. RAL-634 starvation verify (--post-linear)
#   5. optional inventory wait (stall default on) — poll run-inspect until evidence is real
#
# Machine status: posts STARTED/DONE/FAILED/PARTIAL to hermes-mac-land GitHub issue #1 when `gh` available (preflight skips beacon).
#
# Usage:
#   HERMES_AUTO_SURGICAL_LAND=0 curl -fsSL .../hermes-dispatcher-downstream.sh | bash
#   (auto-pins stall run + stack-apply=0 + stall_recovery=1 when run matches default;
#    .11 verified at #110 tip — set HERMES_AUTO_STACK_APPLY=1 only if host drifts)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
LOG="$DIR/dispatcher-downstream.log"
LINEAR_TICKET="${HERMES_RAL793_LINEAR_TICKET:-RAL-793}"
LINEAR_ISSUE_ID="${HERMES_RAL793_LINEAR_ISSUE_ID:-963472c8-cc84-426a-9ed6-79e08566353a}"
DEFAULT_STALL_RUN_ID="${HERMES_DEFAULT_STALL_RUN_ID:-20260826T232521106484Z-2954673}"

# Downstream-only: auto-pin stalled canary when HERMES_AUTO_SURGICAL_LAND=0 (#36 parity)
if [[ "${HERMES_AUTO_SURGICAL_LAND:-}" == "0" ]] && [[ -z "${HERMES_RUN_ID:-}" ]]; then
  export HERMES_RUN_ID="$DEFAULT_STALL_RUN_ID"
  echo "INFO: HERMES_RUN_ID defaulted to stalled canary run $HERMES_RUN_ID" >&2
fi

AUTO_DISPATCH="${HERMES_AUTO_DISPATCH_RAL793:-1}"
# Stall run: stack-apply defaults OFF — .11 verified at #110 tip (b3b82bf2… / a535cb7) @ 00:05Z.
if [[ "${HERMES_RUN_ID:-}" == "$DEFAULT_STALL_RUN_ID" ]]; then
  AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
  STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
  WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
else
  AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-1}"
  STALL_RECOVERY="${HERMES_STALL_RECOVERY:-}"
  WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-0}"
fi
AUTO_INSPECT="${HERMES_AUTO_INSPECT_RAL793:-}"
INSPECT_OUT="$DIR/ral793-inspect.out"
GH_STATUS_ISSUE="${HERMES_MAC_LAND_STATUS_ISSUE:-1}"
GH_STATUS_REPO="${HERMES_MAC_LAND_STATUS_REPO:-ilike4movies/hermes-mac-land}"
STARVE_RC=0
INVENTORY_RC=0
INVENTORY_WAIT_SECS="${HERMES_INVENTORY_WAIT_SECS:-180}"
INVENTORY_POLL_SECS="${HERMES_INVENTORY_POLL_SECS:-30}"

_contract="$DIR/hermes-ral793-contract-install.sh"
[[ -x "$_contract" ]] || _contract="$ROOT/shared-scripts/hermes-ral793-contract-install.sh"

_inspect="$DIR/hermes-ral793-run-inspect.sh"
[[ -x "$_inspect" ]] || _inspect="$ROOT/shared-scripts/hermes-ral793-run-inspect.sh"

_starve="$DIR/hermes-ral634-starvation-verify.sh"
[[ -x "$_starve" ]] || _starve="$ROOT/shared-scripts/hermes-ral634-starvation-verify.sh"

_stack_apply="$DIR/hermes-moltbot-stack-apply-via-ssh.sh"
[[ -x "$_stack_apply" ]] || _stack_apply="$ROOT/shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh"

_load_hermes_ssh_env() {
  local f key val
  for f in "${HOME}/.hermes/.env" /opt/moltbot/config/secrets.env "${HOME}/.openclaw/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*|HERMES_HOST_SSH_PRIVATE_KEY=*)
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

_has_ssh_key() {
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && return 0
  [[ -s "${DIR}/host-ssh-key" ]] && return 0
  [[ -f "${HOME}/.hermes/.env" ]] && grep -q '^HERMES_HOST_SSH_PRIVATE_KEY=' "${HOME}/.hermes/.env" 2>/dev/null && return 0
  return 1
}

_has_linear_key() {
  [[ -n "${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}" ]] && return 0
  return 1
}

_preflight_env() {
  local reason=""
  if [[ "${COMPOSER_REPO_URL:-}" == *ooterverse* ]] || [[ "${COMPOSER_REPO_URL:-}" == *Ooterverse* ]]; then
    reason="wrong_repo=Ooterverse (need ilike4movies/hermes-mac-land + LEGACY Hermes .11 env)"
  fi
  # Always fail-fast when credentialed path is impossible (not only when COMPOSER_REPO_URL is set).
  if [[ -z "$reason" ]] && [[ -z "${TS_AUTHKEY:-}" ]] && ! _has_ssh_key; then
    reason="missing_secrets=TS_AUTHKEY+HERMES_HOST_SSH_PRIVATE_KEY (attach Runtime Secrets at boot)"
  elif [[ -z "$reason" ]] && [[ -z "${TS_AUTHKEY:-}" ]] && ! command -v tailscale >/dev/null 2>&1; then
    reason="missing_tailscale=TS_AUTHKEY unset and tailscale not installed"
  fi
  if [[ -n "$reason" ]]; then
    echo "FAIL preflight: $reason" >&2
    echo "  COMPOSER_REPO_URL=${COMPOSER_REPO_URL:-unset}" >&2
    echo "  fix: start NEW cloud agent on hermes-mac-land with LEGACY Hermes .11 secrets" >&2
    echo "  or Mac Hermes: Right-click → Open HERMES-DOWNSTREAM-RAL793-STALL.command (not double-click)" >&2
    return 1
  fi
  return 0
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

# Return 0 if inventory evidence looks real (not missing / not placeholder "pending").
_inventory_evidence_ok() {
  local out="$1"
  if printf '%s\n' "$out" | grep -q 'evidence/RAL-793-inventory.md --- MISSING'; then
    return 1
  fi
  # Capture a short window after the inventory header.
  local snippet
  snippet="$(printf '%s\n' "$out" | awk '/evidence\/RAL-793-inventory.md/{flag=1; next} flag{print; if(++n>=12) exit}')"
  if [[ -z "$snippet" ]]; then
    return 1
  fi
  # Placeholder written by contract-install preflight is not evidence.
  if printf '%s\n' "$snippet" | grep -Eqi '^(pending|TODO|placeholder)[[:space:]]*$' \
     && ! printf '%s\n' "$snippet" | grep -Eqi 'EP0[4-9]|EP1[0-4]|artifact|workspace|allow_path|script|tts|remotion'; then
    return 1
  fi
  if printf '%s\n' "$snippet" | grep -Eqi 'EP0[4-9]|EP1[0-4]|artifact|workspace|/opt/moltbot|script|tts|remotion|inventory'; then
    return 0
  fi
  # Any non-trivial multi-line content beyond "pending" counts as progress.
  local lines
  lines="$(printf '%s\n' "$snippet" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$lines" -ge 3 ]]
}

_fetch_script() {
  local name="$1" dest="$2"
  local pin="${HERMES_MAC_LAND_PIN:-main}"
  echo "fetching $name from $pin" | tee -a "$LOG"
  curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${pin}/shared-scripts/$name" \
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

if [[ ! -x "$_stack_apply" ]]; then
  _fetch_script "hermes-moltbot-stack-apply-via-ssh.sh" "$DIR/hermes-moltbot-stack-apply-via-ssh.sh"
  _stack_apply="$DIR/hermes-moltbot-stack-apply-via-ssh.sh"
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

if [[ -z "$STALL_RECOVERY" ]] && [[ -n "${HERMES_RUN_ID:-}" ]]; then
  STALL_RECOVERY=1
fi

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"
USER_NAME="$(whoami 2>/dev/null || echo unknown)"

if ! _preflight_env 2>&1 | tee -a "$LOG"; then
  echo "SKIP GitHub beacon (preflight expected on wrong env — use Mac or LEGACY .11)" >&2
  exit 1
fi

_post_github_status "## Downstream STARTED @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
chain: inspect(auto=$AUTO_INSPECT) → contract install → stack-apply(auto=$AUTO_STACK_APPLY) → DISPATCH-NOW (auto=$AUTO_DISPATCH) → RAL-634 verify → inventory-wait(auto=$WAIT_INVENTORY)
stall_recovery=$STALL_RECOVERY run=${HERMES_RUN_ID:-unset}
log: \`$LOG\`"

echo "== Hermes dispatcher downstream @ $WHEN ==" | tee -a "$LOG"

if [[ "$AUTO_INSPECT" == "1" ]]; then
  echo "== Step 0: RAL-793 run inspect (read-only) ==" | tee -a "$LOG"
  _inspect_args=(--post-linear)
  [[ -n "${HERMES_RUN_ID:-}" ]] && _inspect_args=(--run "$HERMES_RUN_ID" --post-linear)
  if bash "$_inspect" "${_inspect_args[@]}" 2>&1 | tee -a "$LOG" | tee "$INSPECT_OUT"; then
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
if [[ "$AUTO_STACK_APPLY" == "1" ]]; then
  echo "== Step 2: governed stack-apply (moltbot main → .11) ==" | tee -a "$LOG"
  if bash "$_stack_apply" --post-linear 2>&1 | tee -a "$LOG"; then
    echo "OK stack-apply" | tee -a "$LOG"
  else
    echo "FAIL: stack-apply failed — not continuing" | tee -a "$LOG"
    _post_github_status "## Downstream FAILED @ $WHEN

step=stack-apply
host=\`$HOST\` user=\`$USER_NAME\`
See log: \`$LOG\`"
    exit 1
  fi
else
  echo "SKIP Step 2: HERMES_AUTO_STACK_APPLY=0" | tee -a "$LOG"
fi
echo "" | tee -a "$LOG"
if [[ "$AUTO_DISPATCH" == "1" ]]; then
  echo "== Step 3: DISPATCH-NOW $LINEAR_TICKET (Linear interrupt) ==" | tee -a "$LOG"
  if ! _has_linear_key; then
    echo "FAIL: AUTO_DISPATCH=1 but LINEAR_API_KEY/LINEAR_API_TOKEN unset — cannot post DISPATCH-NOW" | tee -a "$LOG"
    echo "  fix: set LINEAR_API_KEY in ~/.hermes/.env (Mac) or Runtime Secrets (cloud)" | tee -a "$LOG"
    _post_github_status "## Downstream FAILED @ $WHEN

step=DISPATCH-NOW
reason=missing LINEAR_API_KEY/LINEAR_API_TOKEN
host=\`$HOST\` user=\`$USER_NAME\`
See log: \`$LOG\`"
    exit 1
  fi
  DISPATCH_BODY="DISPATCH-NOW $LINEAR_TICKET"
  STALL_DISPATCH_PASSES=1
  STALL_DISPATCH_WAIT_SECS="${HERMES_STALL_DISPATCH_WAIT_SECS:-90}"
  if [[ "$STALL_RECOVERY" == "1" ]]; then
    # Stale CLAIM older than movement SLA (300s) may need two interrupts:
    # pass 1 resumes (recovery_attempts=0) or fails stale CLAIM (SLA exceeded);
    # pass 2 reopens from FAILED under pinned contract. Second pass is a no-op
    # if pass 1 already reached WORKING.
    STALL_DISPATCH_PASSES=2
    _post_linear_comment "## Stall recovery @ $WHEN

Run \`${HERMES_RUN_ID:-unknown}\` was CLAIMED before contract was on registry (~10h+ silent). Contract install completed.

Posting **two** \`DISPATCH-NOW\` passes (${STALL_DISPATCH_WAIT_SECS}s apart):
1. resume recovered claim **or** fail stale CLAIM (movement SLA 300s)
2. reopen from FAILED under pinned contract if pass 1 terminalized the zombie

Expect \`evidence/RAL-793-inventory.md\` — not WORK-PACKET-DONE alone." || true
  fi
  _dispatch_ok=0
  _pass=1
  while [[ "$_pass" -le "$STALL_DISPATCH_PASSES" ]]; do
    if [[ "$_pass" -gt 1 ]]; then
      echo "WAIT ${STALL_DISPATCH_WAIT_SECS}s before DISPATCH-NOW pass $_pass/$STALL_DISPATCH_PASSES" | tee -a "$LOG"
      sleep "$STALL_DISPATCH_WAIT_SECS"
      _post_linear_comment "## Stall recovery pass $_pass/$STALL_DISPATCH_PASSES @ $(date -u +%Y-%m-%dT%H:%M:%SZ)

Pass 1 may have resumed the claim or failed it as \`claimed_without_executor_movement\`. Pass 2 reopens from FAILED under pinned contract (no-op if already WORKING)." || true
    fi
    if _post_linear_comment "$DISPATCH_BODY"; then
      echo "OK posted Linear interrupt comment (pass $_pass/$STALL_DISPATCH_PASSES): $DISPATCH_BODY" | tee -a "$LOG"
      _dispatch_ok=1
    else
      echo "WARN: could not post DISPATCH-NOW pass $_pass — Linear API rejected" | tee -a "$LOG"
    fi
    _pass=$((_pass + 1))
  done
  if [[ "$_dispatch_ok" -ne 1 ]]; then
    echo "FAIL: DISPATCH-NOW did not post (auto=$AUTO_DISPATCH) — fail-closed" | tee -a "$LOG"
    _post_github_status "## Downstream FAILED @ $WHEN

step=DISPATCH-NOW
reason=no successful Linear interrupt post
host=\`$HOST\` user=\`$USER_NAME\`
See log: \`$LOG\`"
    exit 1
  fi
  _post_linear_comment "## Auto-dispatch @ $WHEN

Posted \`$DISPATCH_BODY\` ×${STALL_DISPATCH_PASSES} after contract install/readback (stall_recovery=$STALL_RECOVERY). Expect CLAIMED + \`evidence/RAL-793-inventory.md\` — not WORK-PACKET-DONE alone." || true
else
  echo "SKIP Step 3: HERMES_AUTO_DISPATCH_RAL793=0 — post DISPATCH-NOW manually" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "== Step 4: RAL-634 starvation verify ==" | tee -a "$LOG"
if bash "$_starve" --post-linear 2>&1 | tee -a "$LOG"; then
  STARVE_RC=0
else
  STARVE_RC=$?
  echo "WARN: RAL-634 verify failed — see $LOG" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
INVENTORY_STATUS="skipped"
if [[ "$WAIT_INVENTORY" == "1" ]]; then
  echo "== Step 5: wait for inventory evidence (up to ${INVENTORY_WAIT_SECS}s) ==" | tee -a "$LOG"
  _deadline=$(( $(date +%s) + INVENTORY_WAIT_SECS ))
  _attempt=0
  while true; do
    _attempt=$((_attempt + 1))
    _now="$(date +%s)"
    _inspect_args=(--post-linear)
    [[ -n "${HERMES_RUN_ID:-}" ]] && _inspect_args=(--run "$HERMES_RUN_ID" --post-linear)
    _poll_out="$DIR/ral793-inventory-poll-$_attempt.out"
    if bash "$_inspect" "${_inspect_args[@]}" >"$_poll_out" 2>&1; then
      cat "$_poll_out" | tee -a "$LOG" >/dev/null
      if _inventory_evidence_ok "$(cat "$_poll_out")"; then
        echo "OK inventory evidence present (attempt $_attempt)" | tee -a "$LOG"
        INVENTORY_STATUS="present"
        INVENTORY_RC=0
        break
      fi
      echo "INFO: inventory still pending/placeholder (attempt $_attempt)" | tee -a "$LOG"
    else
      cat "$_poll_out" | tee -a "$LOG" >/dev/null || true
      echo "WARN: inventory poll inspect failed (attempt $_attempt)" | tee -a "$LOG"
    fi
    if [[ "$_now" -ge "$_deadline" ]]; then
      echo "FAIL: inventory evidence not ready after ${INVENTORY_WAIT_SECS}s" | tee -a "$LOG"
      INVENTORY_STATUS="missing"
      INVENTORY_RC=1
      break
    fi
    _sleep="$INVENTORY_POLL_SECS"
    _remain=$((_deadline - _now))
    [[ "$_sleep" -gt "$_remain" ]] && _sleep="$_remain"
    [[ "$_sleep" -lt 1 ]] && _sleep=1
    echo "WAIT ${_sleep}s before inventory re-inspect" | tee -a "$LOG"
    sleep "$_sleep"
  done
else
  echo "SKIP Step 5: HERMES_WAIT_INVENTORY=0" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "DONE downstream @ $WHEN" | tee -a "$LOG"
echo "  Expect inventory evidence on $LINEAR_TICKET (evidence/RAL-793-inventory.md)" | tee -a "$LOG"
echo "  Do NOT treat prior WORK-PACKET-DONE as objective closure" | tee -a "$LOG"

if [[ "$STARVE_RC" -eq 0 && "$INVENTORY_RC" -eq 0 ]]; then
  _post_github_status "## Downstream DONE @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
stall_recovery: $STALL_RECOVERY
contract install: OK
stack-apply: auto=$AUTO_STACK_APPLY
DISPATCH-NOW: auto=$AUTO_DISPATCH (stall dual-pass when stall_recovery=1; fail-closed)
RAL-634 verify: PASS
inventory wait: $INVENTORY_STATUS (auto=$WAIT_INVENTORY)

Watch Linear for inventory evidence on $LINEAR_TICKET — not WORK-PACKET-DONE alone."
else
  _post_github_status "## Downstream PARTIAL @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
stall_recovery: $STALL_RECOVERY
contract install: OK
stack-apply: auto=$AUTO_STACK_APPLY
DISPATCH-NOW: auto=$AUTO_DISPATCH (stall dual-pass when stall_recovery=1; fail-closed)
RAL-634 verify: $([[ "$STARVE_RC" -eq 0 ]] && echo PASS || echo "FAIL (rc=$STARVE_RC)")
inventory wait: $INVENTORY_STATUS (auto=$WAIT_INVENTORY)

See log: \`$LOG\`
Do NOT mark canary Done until inventory evidence is real."
  if [[ "$STARVE_RC" -ne 0 ]]; then
    exit "$STARVE_RC"
  fi
  exit "$INVENTORY_RC"
fi
