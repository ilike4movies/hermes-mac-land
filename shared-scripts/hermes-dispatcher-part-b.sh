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
# Tip #150: contract-install SEED embeds EP04/workspace/tts in comments — must NOT false-pass.
_inventory_evidence_ok() {
  local out="$1"
  if printf '%s\n' "$out" | grep -q 'evidence/RAL-793-inventory.md --- MISSING'; then
    return 1
  fi
  # Capture a short window after the inventory header.
  local snippet
  snippet="$(printf '%s\n' "$out" | awk '/evidence\/RAL-793-inventory.md/{flag=1; next} flag{print; if(++n>=20) exit}')"
  if [[ -z "$snippet" ]]; then
    return 1
  fi
  # Explicit SEED / placeholder reject (tip #150) — before any EP/workspace keyword accept.
  if printf '%s\n' "$snippet" | grep -Eqi 'SEED|NOT live inventory|inventory-wait cannot false-pass|Seed ≠ Done|Seed != Done'; then
    return 1
  fi
  local first
  first="$(printf '%s\n' "$snippet" | sed '/^[[:space:]]*$/d' | head -n 1 | tr -d '\r')"
  if printf '%s\n' "$first" | grep -Eqi '^(pending|TODO|placeholder)[[:space:]]*$'; then
    return 1
  fi
  # Live inventory: dated header / hashes / host verify — not archaeology keywords alone.
  if printf '%s\n' "$snippet" | grep -Eqi 'LIVE inventory|live host verify|sha256=|pre_sha=|host verify OK|EP04.*(PRESENT|OK|hash|sha)|artifact map'; then
    return 0
  fi
  if printf '%s\n' "$snippet" | grep -Eqi 'EP0[4-9]|EP1[0-4]' \
     && printf '%s\n' "$snippet" | grep -Eqi 'work/ep0|/opt/moltbot/workspace|narration\.wav|video\.mp4|metadata\.json'; then
    return 0
  fi
  return 1
}

_fetch_script() {
  local name="$1" dest="$2"
  local pin="${HERMES_MAC_LAND_PIN:-main}"
  echo "fetching $name from $pin" | tee -a "$LOG"
  curl -fsSL "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${pin}/shared-scripts/$name" \
    -o "$dest"
  chmod +x "$dest"
}

# Tip #145: fetch on missing file (-f), then chmod +x before bash (0644 curl class).
_ensure_helper() {
  # $1=varname $2=basename
  local _var="$1" _name="$2" _path
  eval "_path=\"\${$_var}\""
  if [[ ! -f "$_path" ]]; then
    _fetch_script "$_name" "$DIR/$_name"
    eval "$_var=\"\$DIR/$_name\""
    eval "_path=\"\$DIR/$_name\""
  fi
  chmod +x "$_path" 2>/dev/null || true
}
_ensure_helper _contract hermes-ral793-contract-install.sh
_ensure_helper _inspect hermes-ral793-run-inspect.sh
_ensure_helper _starve hermes-ral634-starvation-verify.sh
_ensure_helper _stack_apply hermes-moltbot-stack-apply-via-ssh.sh

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

STALL_AGE_SECS=0
if [[ -n "${HERMES_RUN_ID:-}" ]]; then
  STALL_AGE_SECS="$(_stall_age_secs "$HERMES_RUN_ID")"
fi
ZOMBIE="${HERMES_STALL_ZOMBIE:-}"
if [[ -z "$ZOMBIE" ]]; then
  if [[ "$STALL_RECOVERY" == "1" ]] && [[ "$STALL_AGE_SECS" -ge 3600 ]]; then
    ZOMBIE=1
  else
    ZOMBIE=0
  fi
fi
STALL_AGE_HOURS="$(( STALL_AGE_SECS / 3600 ))"

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
stall_recovery=$STALL_RECOVERY zombie=$ZOMBIE stall_age=${STALL_AGE_SECS}s run=${HERMES_RUN_ID:-unset}
log: \`$LOG\`"

echo "== Hermes dispatcher downstream @ $WHEN ==" | tee -a "$LOG"
if [[ -n "${HERMES_RUN_ID:-}" ]]; then
  echo "stall_age=${STALL_AGE_SECS}s (~${STALL_AGE_HOURS}h) zombie=$ZOMBIE run=${HERMES_RUN_ID}" | tee -a "$LOG"
fi

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
    if [[ "$ZOMBIE" == "1" ]]; then
      # Ultra-stale CLAIM (≥1h silent): triple DISPATCH-NOW ladder @ 120s.
      STALL_DISPATCH_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
      STALL_DISPATCH_WAIT_SECS="${HERMES_STALL_DISPATCH_WAIT_SECS:-120}"
