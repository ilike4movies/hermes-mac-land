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
echo "tip through #174 (soft-hold CURRENT DTEND stamp tip#174; Dropbox WAKE tip#173; NAG #172 Path C; ONE-SHOT #171 Path C tabs; FALLBACK b2b5fc4); approve tip CURRENT_AUTHURL or RAL-823"
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
  # Tip #159: pre-export GitHub status token so curl fallback works if gh hangs mid-post.
  if [[ -z "${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}" ]] && command -v gh >/dev/null 2>&1; then
    _tok="$(timeout 5 gh auth token 2>/dev/null || true)"
    if [[ -n "$_tok" ]]; then
      export HERMES_STATUS_GITHUB_TOKEN="$_tok"
      echo "OK tip #159 status token exported from gh 