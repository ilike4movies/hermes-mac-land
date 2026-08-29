      _post_linear_comment "## Zombie reclaim @ $WHEN

Run \`${HERMES_RUN_ID:-unknown}\` silent ~${STALL_AGE_HOURS}h+ (${STALL_AGE_SECS}s since CLAIM). Contract install completed.

Posting **three** \`DISPATCH-NOW\` passes (${STALL_DISPATCH_WAIT_SECS}s apart) — **zombie reclaim** ladder:
1. fail stale CLAIM (movement SLA 300s) **or** resume recovered claim
2. reopen from FAILED under pinned contract
3. second reopen if still stuck after pass 2

Expect \`evidence/RAL-793-inventory.md\` — not WORK-PACKET-DONE alone." || true
    else
      # Stale CLAIM older than movement SLA (300s) may need two interrupts:
      # pass 1 resumes (recovery_attempts=0) or fails stale CLAIM (SLA exceeded);
      # pass 2 reopens from FAILED under pinned contract. Second pass is a no-op
      # if pass 1 already reached WORKING.
      STALL_DISPATCH_PASSES=2
      _post_linear_comment "## Stall recovery @ $WHEN

Run \`${HERMES_RUN_ID:-unknown}\` was CLAIMED before contract was on registry (~${STALL_AGE_HOURS}h silent, ${STALL_AGE_SECS}s). Contract install completed.

Posting **two** \`DISPATCH-NOW\` passes (${STALL_DISPATCH_WAIT_SECS}s apart):
1. resume recovered claim **or** fail stale CLAIM (movement SLA 300s)
2. reopen from FAILED under pinned contract if pass 1 terminalized the zombie

Expect \`evidence/RAL-793-inventory.md\` — not WORK-PACKET-DONE alone." || true
    fi
  fi
  _dispatch_ok=0
  _pass=1
  while [[ "$_pass" -le "$STALL_DISPATCH_PASSES" ]]; do
    if [[ "$_pass" -gt 1 ]]; then
      echo "WAIT ${STALL_DISPATCH_WAIT_SECS}s before DISPATCH-NOW pass $_pass/$STALL_DISPATCH_PASSES" | tee -a "$LOG"
      sleep "$STALL_DISPATCH_WAIT_SECS"
      if [[ "$ZOMBIE" == "1" ]]; then
        _post_linear_comment "## Zombie reclaim pass $_pass/$STALL_DISPATCH_PASSES @ $(date -u +%Y-%m-%dT%H:%M:%SZ)

Pass 1 may have failed stale CLAIM as \`claimed_without_executor_movement\`. Pass 2+ reopen from FAILED under pinned contract (no-op if already WORKING). Pass 3 is a second reopen if still stuck." || true
      else
        _post_linear_comment "## Stall recovery pass $_pass/$STALL_DISPATCH_PASSES @ $(date -u +%Y-%m-%dT%H:%M:%SZ)

Pass 1 may have resumed the claim or failed it as \`claimed_without_executor_movement\`. Pass 2 reopens from FAILED under pinned contract (no-op if already WORKING)." || true
      fi
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

Posted \`$DISPATCH_BODY\` ×${STALL_DISPATCH_PASSES} after contract install/readback (stall_recovery=$STALL_RECOVERY zombie=$ZOMBIE). Expect CLAIMED + \`evidence/RAL-793-inventory.md\` — not WORK-PACKET-DONE alone." || true
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

_DISPATCH_MODE="single-pass"
if [[ "$STALL_RECOVERY" == "1" ]]; then
  if [[ "$ZOMBIE" == "1" ]]; then
    _DISPATCH_MODE="zombie triple-pass"
  else
    _DISPATCH_MODE="stall dual-pass"
  fi
fi

# Tip #151: bare "## Downstream DONE" only when live inventory is present.
# WAIT_INVENTORY=0 used to leave INVENTORY_RC=0 and post DONE with
# "inventory wait: skipped" — that false-counts obj5 cred_DONE gates.
if [[ "$STARVE_RC" -eq 0 && "$INVENTORY_STATUS" == "present" && "$INVENTORY_RC" -eq 0 ]]; then
  # Tip #159: fail-closed if issue #1 Downstream DONE beacon did not post (obj5/NAG depend on it).
  if ! _post_github_status "## Downstream DONE @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
stall_recovery: $STALL_RECOVERY zombie: $ZOMBIE stall_age: ${STALL_AGE_SECS}s
contract install: OK
stack-apply: auto=$AUTO_STACK_APPLY
DISPATCH-NOW: auto=$AUTO_DISPATCH ($_DISPATCH_MODE when stall_recovery=1; fail-closed)
RAL-634 verify: PASS
inventory wait: present (auto=$WAIT_INVENTORY)

Watch Linear for inventory evidence on $LINEAR_TICKET — not WORK-PACKET-DONE alone."; then
    echo "FAIL: Downstream DONE beacon did not post to ${GH_STATUS_REPO}#${GH_STATUS_ISSUE} (tip #159 fail-closed)" | tee -a "$LOG"
    exit 2
  fi
elif [[ "$STARVE_RC" -eq 0 && "$WAIT_INVENTORY" != "1" ]]; then
  _post_github_status "## Downstream COMPLETE (inventory deferred) @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
stall_recovery: $STALL_RECOVERY zombie: $ZOMBIE stall_age: ${STALL_AGE_SECS}s
contract install: OK
stack-apply: auto=$AUTO_STACK_APPLY
DISPATCH-NOW: auto=$AUTO_DISPATCH ($_DISPATCH_MODE when stall_recovery=1; fail-closed)
RAL-634 verify: PASS
inventory wait: skipped (auto=$WAIT_INVENTORY)

Tip #151: not counted as obj5 Downstream DONE — set HERMES_WAIT_INVENTORY=1 for canary."
else
  _post_github_status "## Downstream PARTIAL @ $WHEN

host=\`$HOST\` user=\`$USER_NAME\`
run inspect: auto=$AUTO_INSPECT
stall_recovery: $STALL_RECOVERY zombie: $ZOMBIE stall_age: ${STALL_AGE_SECS}s
contract install: OK
stack-apply: auto=$AUTO_STACK_APPLY
DISPATCH-NOW: auto=$AUTO_DISPATCH ($_DISPATCH_MODE when stall_recovery=1; fail-closed)
RAL-634 verify: $([[ "$STARVE_RC" -eq 0 ]] && echo PASS || echo "FAIL (rc=$STARVE_RC)")
inventory wait: $INVENTORY_STATUS (auto=$WAIT_INVENTORY)

See log: \`$LOG\`
Do NOT mark canary Done until inventory evidence is real."
  if [[ "$STARVE_RC" -ne 0 ]]; then
    exit "$STARVE_RC"
  fi
  # deferred path above already returned; inventory miss/timeout → non-zero
  exit "${INVENTORY_RC:-1}"
fi
