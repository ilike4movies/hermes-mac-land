#!/bin/bash
# HERMES-ONE-SHOT-UNBLOCK.command — Right-click → Open on Mac Hermes (not double-click)
# Single click critical path for stalled canary recovery:
#   0) Open Tailscale admin + tip CURRENT_AUTHURL (approve cloud waiter) early
#   0a) Open Linear operator ticket (RAL-823) early
#   0b) Open Web UI workflow create + Raw paste tabs early (parallel with STALL)
#   0c) Install 5-min Downstream nag LaunchAgent (auto ONE-SHOT until issue #1 shows Downstream DONE)
#   1) Try STALL downstream (SSH/Tailscale to .11) — fastest when mesh works
#   2) On STALL fail → Phase 2 ENABLE (install workflow + gh workflow run; tip #127 uses HERMES_GH_WORKFLOW_PAT)
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
export HERMES_INVENTORY_WAIT_SECS="${HERMES_INVENTORY_WAIT_SECS:-900}"
export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
FALLBACK_ACTIONS="${HERMES_ONE_SHOT_FALLBACK_ACTIONS:-1}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes ONE-SHOT UNBLOCK (run=$HERMES_RUN_ID) pin=$PIN ==="
echo "zombie=$HERMES_STALL_ZOMBIE zombie_passes=$HERMES_STALL_ZOMBIE_PASSES stall_recovery=$HERMES_STALL_RECOVERY"
echo "tip through #179 (Phase2 secrets tab tip#179; STALL nag tip#178; Path C tip#177; NAG Raw tip#176; FALLBACK b2b5fc4); approve tip CURRENT_AUTHURL or RAL-823"
echo "Host: $(hostname) user: $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Status inbox: https://github.com/${REPO}/issues/1"
echo "Path: Web UI early + STALL first; on fail → ENABLE-ACTIONS (fallback=$FALLBACK_ACTIONS)"
# Spoken wake so Mac session notices even if browser tabs are buried.
if [[ "${HERMES_ONE_SHOT_SPEAK:-1}" == "1" ]] && command -v say >/dev/null 2>&1; then
  say -v Samantha "Hermes ONE-SHOT starting. Approve Tailscale or let STALL run." 2>/dev/null || true
fi

_load_mac_hermes_env() {
  local f="${HOME}/.hermes/.env"
  [[ -f "$f" ]] || return 0
  local key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ''|\#*) continue ;;
      LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|HERMES_HOST_SSH_PRIVATE_KEY=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*|TS_AUTHKEY=*|HERMES_GH_WORKFLOW_PAT=*)
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
  if [[ -z "${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}" ]] && command -v gh >/dev/null 2>&1; then
    _tok="$(timeout 5 gh auth token 2>/dev/null || true)"
    if [[ -n "$_tok" ]]; then
      export HERMES_STATUS_GITHUB_TOKEN="$_tok"
      echo "OK tip #159 status token exported from gh auth"
    else
      echo "WARN tip #159: no gh auth token — Downstream DONE beacon may fail-closed; run: gh auth login"
    fi
  fi

}

_open_tailscale_approve_early() {
  if [[ "${HERMES_ONE_SHOT_OPEN_TAILSCALE:-1}" != "1" ]]; then return 0; fi
  local ADMIN="https://login.tailscale.com/admin/machines"
  local AUTH="" url f="/tmp/hermes-current-authurl-$$.txt"
  for url in "https://raw.githubusercontent.com/${REPO}/${PIN}/CURRENT_AUTHURL.md" "https://raw.githubusercontent.com/${REPO}/main/CURRENT_AUTHURL.md"; do
    if curl -fsSL "$url" -o "$f" 2>/dev/null; then AUTH=$(grep -Eo 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' "$f" | head -1 || true); [[ -n "$AUTH" ]] && break; fi; rm -f "$f"
  done; rm -f "$f"
  open "$ADMIN" 2>/dev/null || true; [[ -n "$AUTH" ]] && open "$AUTH" 2>/dev/null || true
}

_open_operator_linear_early() {
  if [[ "${HERMES_ONE_SHOT_OPEN_LINEAR:-1}" != "1" ]]; then return 0; fi
  open "${HERMES_OPERATOR_LINEAR_URL:-https://linear.app/ilike4/issue/RAL-823/operator-mac-one-shot-tailscale-approve-now-authurl-1d0d8050-canary}" 2>/dev/null || true
}

_open_webui_workflow_early() {
  if [[ "${HERMES_ONE_SHOT_OPEN_WEBUI_EARLY:-1}" != "1" ]]; then return 0; fi
  open "https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml" 2>/dev/null || true
  open "https://github.com/${REPO}/raw/main/ci/downstream-stall.yml" 2>/dev/null || true
  open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
}

_open_pathc_reconnect_early() {
  if [[ "${HERMES_ONE_SHOT_OPEN_PATHC_RECONNECT:-1}" != "1" ]]; then return 0; fi
  open "${HERMES_DROPBOX_WAKE_URL:-https://www.dropbox.com/scl/fi/t8p9b7qqnrrbrijhn1r1j/WAKE-1d0d8050-tip169.txt?rlkey=4p6zu480sotpw7lb34rjkbxli&dl=1}" 2>/dev/null || true
  open "${HERMES_ZAPIER_GH_RECONNECT_URL:-https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336}" 2>/dev/null || true
  open "${HERMES_ZAPIER_CAL_RECONNECT_URL:-https://mcp.zapier.com/api/v1/connect-auth/GoogleCalendarCLIAPI?accountId=12547336&connectionId=55516487}" 2>/dev/null || true
}

_install_downstream_nag() { [[ "${HERMES_ONE_SHOT_INSTALL_NAG:-1}" != "1" ]] && return 0; local NAG="/tmp/hermes-install-downstream-nag-oneshot-$$.command" url; rm -f "$NAG"; for url in "https://raw.githubusercontent.com/${REPO}/${PIN}/HERMES-INSTALL-DOWNSTREAM-NAG.command" "https://raw.githubusercontent.com/${REPO}/main/HERMES-INSTALL-DOWNSTREAM-NAG.command"; do if curl -fsSL "$url" -o "$NAG" && grep -q 'com.hermes.downstream-nag' "$NAG" && grep -q '_machine_downstream_done' "$NAG" && grep -q 'Downstream DONE @' "$NAG"; then chmod +x "$NAG"; HERMES_NAG_NONINTERACTIVE=1 bash "$NAG" || true; rm -f "$NAG"; return 0; fi; rm -f "$NAG"; done; return 0; }

_run_stall() { echo "=== Phase 1: STALL downstream (SSH/.11) ==="; local SCRIPT="/tmp/hermes-dispatcher-downstream-oneshot-$$.sh" ONCE="/tmp/hermes-cloud-run-downstream-once-$$.sh" FETCHED="" url DOWNSTREAM_PIN="${HERMES_DOWNSTREAM_PIN:-}"; rm -f "$SCRIPT" "$ONCE"; _is_good_once(){ local f="$1"; grep -q 'Tip #142' "$f" && grep -q 'hermes-dispatcher-downstream.sh' "$f" && grep -q 'flock' "$f"; }; _is_good_downstream(){ local f="$1"; grep -q 'ONE-SHOT safe entrypoint' "$f" && grep -q '_parts_integrity_ok' "$f" && grep -qE 'b2b5fc4|HERMES_STATUS_GITHUB_TOKEN|Downstream DONE beacon did not post' "$f"; }; for url in "https://raw.githubusercontent.com/${REPO}/${PIN}/shared-scripts/hermes-cloud-run-downstream-once.sh" "https://raw.githubusercontent.com/${REPO}/main/shared-scripts/hermes-cloud-run-downstream-once.sh"; do if curl -fsSL "$url" -o "$ONCE" && _is_good_once "$ONCE"; then chmod +x "$ONCE"; set +e; bash "$ONCE"; local rc=$?; set -e; rm -f "$ONCE"; [[ "$rc" -eq 0 ]] && return 0; break; fi; rm -f "$ONCE"; done; local urls=("https://raw.githubusercontent.com/${REPO}/${PIN}/shared-scripts/hermes-dispatcher-downstream.sh" "https://raw.githubusercontent.com/${REPO}/main/shared-scripts/hermes-dispatcher-downstream.sh"); [[ -n "$DOWNSTREAM_PIN" ]] && urls+=("https://raw.githubusercontent.com/${REPO}/${DOWNSTREAM_PIN}/shared-scripts/hermes-dispatcher-downstream.sh"); for url in "${urls[@]}"; do if curl -fsSL "$url" -o "$SCRIPT" && _is_good_downstream "$SCRIPT"; then FETCHED="$url"; break; fi; rm -f "$SCRIPT"; done; [[ -z "$FETCHED" || ! -s "$SCRIPT" ]] && return 2; chmod +x "$SCRIPT"; set +e; bash "$SCRIPT"; local rc=$?; set -e; [[ "$rc" -eq 0 ]] && return 0; return 1; }

_install_workflow_via_git_push() { local WF_PATH=".github/workflows/downstream-stall.yml" SRC_URL="https://raw.githubusercontent.com/${REPO}/main/ci/downstream-stall.yml" work="/tmp/hermes-wf-git-oneshot-$$" src_file="/tmp/hermes-downstream-stall-yml-git-$$.yml"; rm -rf "$work"; mkdir -p "$work"; curl -fsSL "$SRC_URL" -o "$src_file"; git clone --depth 1 "git@github.com:${REPO}.git" "$work/repo" 2>/dev/null || GIT_TERMINAL_PROMPT=0 gh repo clone "$REPO" "$work/repo" -- --depth 1; mkdir -p "$work/repo/.github/workflows"; cp "$src_file" "$work/repo/${WF_PATH}"; ( cd "$work/repo"; git config user.email hermes-mac-land@local; git config user.name "Hermes ONE-SHOT tip161"; git add "$WF_PATH"; git diff --cached --quiet || git commit -m "ci: enable downstream-stall workflow (tip #161 git fallback)"; git push origin HEAD:main ); rm -rf "$work"; }

_run_enable_actions() {
  echo "=== Phase 2: ENABLE Downstream Actions (local gh) ==="
  _load_mac_hermes_env || true
  [[ -n "${HERMES_GH_WORKFLOW_PAT:-}" ]] && export GH_TOKEN="$HERMES_GH_WORKFLOW_PAT" GITHUB_TOKEN="$HERMES_GH_WORKFLOW_PAT"
  if ! command -v gh >/dev/null 2>&1; then
    open "https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml" 2>/dev/null || true
    open "https://github.com/${REPO}/raw/main/ci/downstream-stall.yml" 2>/dev/null || true
    open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
    return 1
  fi
  gh auth status >/dev/null 2>&1 || return 1
  local WF_PATH=".github/workflows/downstream-stall.yml" SRC_URL="https://raw.githubusercontent.com/${REPO}/main/ci/downstream-stall.yml"
  if ! gh api "repos/${REPO}/contents/${WF_PATH}" --jq .sha >/dev/null 2>&1; then
    local SRC_FILE="/tmp/hermes-downstream-stall-yml-$$.yml" B64
    curl -fsSL "$SRC_URL" -o "$SRC_FILE"; B64=$(base64 < "$SRC_FILE" | tr -d '\n'); rm -f "$SRC_FILE"
    gh api --method PUT "repos/${REPO}/contents/${WF_PATH}" -f message='ci: enable downstream-stall workflow' -f content="$B64" -f branch=main 2>/dev/null || _install_workflow_via_git_push || {
      open "https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml" 2>/dev/null || true
      open "https://github.com/${REPO}/raw/main/ci/downstream-stall.yml" 2>/dev/null || true
      open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
      return 1; }
  fi
  gh workflow run downstream-stall.yml --repo "$REPO" && return 0
  open "https://github.com/${REPO}/actions" 2>/dev/null || true
  open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
  return 1
}

xattr -d com.apple.quarantine "$0" 2>/dev/null || true; chmod +x "$0" 2>/dev/null || true
_preflight_mac_secrets
_open_tailscale_approve_early; _open_operator_linear_early; _open_webui_workflow_early; _open_pathc_reconnect_early; _install_downstream_nag
STALL_RC=0; _run_stall || STALL_RC=$?
[[ "$STALL_RC" -eq 0 ]] && { read -r -p "Press Enter to close…" _; exit 0; }
[[ "$FALLBACK_ACTIONS" != "1" ]] && exit "$STALL_RC"
_run_enable_actions && exit 0
exit 1
