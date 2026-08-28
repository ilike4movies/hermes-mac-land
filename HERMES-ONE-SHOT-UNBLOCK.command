#!/bin/bash
# HERMES-ONE-SHOT-UNBLOCK.command — Right-click → Open on Mac Hermes (not double-click)
# Single click critical path for stalled canary recovery:
#   1) Try STALL downstream (SSH/Tailscale to .11) — fastest when mesh works
#   2) On STALL fail → auto ENABLE-DOWNSTREAM-ACTIONS (install workflow + gh workflow run)
# Requires ~/.hermes/.env LINEAR_API_KEY. Prefer this over picking between STALL vs ENABLE.
# Do not put open canary ticket IDs in PR titles when enabling Actions.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-oneshot-unblock-command}"
export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
export HERMES_AUTO_SURGICAL_LAND=0
export HERMES_AUTO_INSPECT_RAL793=1
export HERMES_AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
FALLBACK_ACTIONS="${HERMES_ONE_SHOT_FALLBACK_ACTIONS:-1}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes ONE-SHOT UNBLOCK (run=$HERMES_RUN_ID) pin=$PIN ==="
echo "Host: $(hostname) user: $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Status inbox: https://github.com/${REPO}/issues/1"
echo "Path: STALL first; on fail → ENABLE-ACTIONS (fallback=$FALLBACK_ACTIONS)"

_load_mac_hermes_env() {
  local f="${HOME}/.hermes/.env"
  [[ -f "$f" ]] || return 0
  local key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ''|\#*) continue ;;
      LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|HERMES_HOST_SSH_PRIVATE_KEY=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*|TS_AUTHKEY=*)
        key="${line%%=*}"
        val="${line#*=}"
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        [[ -z "${!key:-}" ]] && export "$key=$val"
        ;;
    esac
  done < "$f"
}

_preflight_mac_secrets() {
  _load_mac_hermes_env || true
  if [[ -z "${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}" ]]; then
    echo ""
    echo "FAILED: LINEAR_API_KEY (or LINEAR_API_TOKEN) missing — required for DISPATCH-NOW + Actions."
    echo " fix: add LINEAR_API_KEY=... to ~/.hermes/.env, then Right-click → Open again."
    osascript -e 'display notification "Add LINEAR_API_KEY to ~/.hermes/.env" with title "Hermes ONE-SHOT preflight FAILED" sound name "Basso"' 2>/dev/null || true
    read -r -p "Press Enter to close…" _
    exit 1
  fi
}

_run_stall() {
  echo ""
  echo "=== Phase 1: STALL downstream (SSH/.11) ==="
  osascript -e 'display notification "Phase 1: STALL downstream on .11…" with title "Hermes ONE-SHOT" sound name "Glass"' 2>/dev/null || true
  local SCRIPT="/tmp/hermes-dispatcher-downstream-oneshot-$$.sh"
  rm -f "$SCRIPT"
  local FETCHED=""
  local url
  for url in \
    "https://raw.githubusercontent.com/${REPO}/${PIN}/shared-scripts/hermes-dispatcher-downstream.sh" \
    "https://raw.githubusercontent.com/${REPO}/main/shared-scripts/hermes-dispatcher-downstream.sh"
  do
    echo "Trying fetch: $url"
    if curl -fsSL "$url" -o "$SCRIPT"; then
      if grep -q 'RAL-793 run inspect' "$SCRIPT" 2>/dev/null \
         && grep -q 'DISPATCH-NOW' "$SCRIPT" 2>/dev/null \
         && grep -q 'WAIT_INVENTORY' "$SCRIPT" 2>/dev/null \
         && grep -q 'fail-closed' "$SCRIPT" 2>/dev/null; then
        FETCHED="$url"
        break
      fi
      rm -f "$SCRIPT"
    fi
  done
  if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
    echo "STALL fetch FAILED"
    return 2
  fi
  chmod +x "$SCRIPT"
  echo "OK fetched: $FETCHED"
  set +e
  bash "$SCRIPT"
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "OK STALL downstream finished for run $HERMES_RUN_ID"
    return 0
  fi
  echo "STALL downstream exited $rc"
  return 1
}

_run_enable_actions() {
  echo ""
  echo "=== Phase 2: ENABLE Downstream Actions (local gh) ==="
  osascript -e 'display notification "Phase 2: enabling GitHub Actions path…" with title "Hermes ONE-SHOT" sound name "Glass"' 2>/dev/null || true
  if ! command -v gh >/dev/null 2>&1; then
    echo "FAILED: gh CLI missing. Install GitHub CLI, then: gh auth login"
    echo "Or web UI: copy ci/downstream-stall.yml → .github/workflows/downstream-stall.yml"
    open "https://github.com/${REPO}/new/main?filename=.github/workflows/downstream-stall.yml" 2>/dev/null || true
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "FAILED: gh not logged in. Run: gh auth login"
    return 1
  fi
  local WF_PATH=".github/workflows/downstream-stall.yml"
  local SRC_URL="https://raw.githubusercontent.com/${REPO}/main/ci/downstream-stall.yml"
  local EXISTING_SHA=""
  if EXISTING_SHA=$(gh api "repos/${REPO}/contents/${WF_PATH}" --jq .sha 2>/dev/null); then
    echo "OK workflow already on main (sha=${EXISTING_SHA:0:12}…)"
  else
    echo "Installing ${WF_PATH}…"
    local SRC_FILE="/tmp/hermes-downstream-stall-yml-$$.yml"
    curl -fsSL "$SRC_URL" -o "$SRC_FILE"
    if ! grep -q 'workflow_dispatch' "$SRC_FILE" || ! grep -q 'hermes-dispatcher-downstream.sh' "$SRC_FILE"; then
      echo "FAILED: downloaded workflow looks incomplete"
      rm -f "$SRC_FILE"
      return 1
    fi
    local B64
    B64=$(base64 < "$SRC_FILE" | tr -d '\n')
    rm -f "$SRC_FILE"
    if ! gh api --method PUT "repos/${REPO}/contents/${WF_PATH}" \
        -f message='ci: enable downstream-stall workflow under .github/workflows' \
        -f content="$B64" \
        -f branch=main >/tmp/hermes-wf-put.json 2>/tmp/hermes-wf-put.err; then
      echo "FAILED: could not write ${WF_PATH} (likely missing workflow scope)"
      echo "Fix: gh auth refresh -h github.com -s workflow"
      cat /tmp/hermes-wf-put.err 2>/dev/null || true
      open "https://github.com/${REPO}/new/main?filename=${WF_PATH}" 2>/dev/null || true
      return 1
    fi
    echo "OK installed ${WF_PATH}"
  fi
  echo "Action secrets required: TS_AUTHKEY HERMES_HOST_SSH_PRIVATE_KEY LINEAR_API_KEY"
  echo "Secrets UI: https://github.com/${REPO}/settings/secrets/actions"
  if gh workflow run downstream-stall.yml --repo "$REPO"; then
    echo "OK workflow_dispatch accepted"
    echo "Watch: https://github.com/${REPO}/actions"
    echo "Inbox: https://github.com/${REPO}/issues/1"
    open "https://github.com/${REPO}/actions" 2>/dev/null || true
    return 0
  fi
  echo "FAILED: gh workflow run — check secrets / Actions enabled"
  open "https://github.com/${REPO}/actions" 2>/dev/null || true
  open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
  return 1
}

xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true
_preflight_mac_secrets

STALL_RC=0
_run_stall || STALL_RC=$?
if [[ "$STALL_RC" -eq 0 ]]; then
  osascript -e 'display notification "STALL OK. Watch Linear + GitHub #1." with title "Hermes ONE-SHOT OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes one shot stall complete. Watch Linear for inventory." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi

echo ""
echo "Phase 1 STALL did not complete (rc=$STALL_RC)."
if [[ "$FALLBACK_ACTIONS" != "1" ]]; then
  echo "HERMES_ONE_SHOT_FALLBACK_ACTIONS=0 — not running Actions fallback."
  osascript -e 'display notification "STALL FAILED. Actions fallback disabled." with title "Hermes ONE-SHOT FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit "$STALL_RC"
fi

if _run_enable_actions; then
  osascript -e 'display notification "Actions path started. Watch Actions + issue #1." with title "Hermes ONE-SHOT PARTIAL→Actions" sound name "Hero"' 2>/dev/null || true
  say "Hermes Actions downstream started. Watch GitHub." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi

osascript -e 'display notification "STALL and Actions both failed. See Terminal." with title "Hermes ONE-SHOT FAILED" sound name "Basso"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit 1
