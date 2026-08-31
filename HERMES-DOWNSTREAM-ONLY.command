#!/bin/bash
# HERMES-DOWNSTREAM-ONLY.command — Right-click → Open on Mac Hermes (not double-click)
# Tip #148: same stall-class defaults as STALL/ONE-SHOT so this alternate entrypoint
# cannot skip zombie reclaim + inventory wait for the silent canary.
# Pins stalled run 20260826T232521106484Z-2954673 and runs full downstream chain:
# inspect → contract install → (stack-apply skipped) → zombie triple DISPATCH-NOW
# → RAL-634 verify → inventory wait (~15 min, fail-closed if DISPATCH/Linear key missing).
# Prefers tip#142 once launcher, then tip/main dispatcher (no stale pin default).
# Requires: Tailscale up + SSH to .11 + LINEAR_API_KEY in ~/.hermes/.env (for DISPATCH-NOW).
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-downstream-only-command}"
export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
export HERMES_AUTO_SURGICAL_LAND=0
export HERMES_AUTO_INSPECT_RAL793=1
export HERMES_AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
export HERMES_INVENTORY_WAIT_SECS="${HERMES_INVENTORY_WAIT_SECS:-900}"
export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DOWNSTREAM ONLY / stall-class (run=$HERMES_RUN_ID) pin=$PIN ==="
echo "stack-apply=$HERMES_AUTO_STACK_APPLY stall_recovery=$HERMES_STALL_RECOVERY wait_inventory=$HERMES_WAIT_INVENTORY"
echo "zombie=$HERMES_STALL_ZOMBIE zombie_passes=$HERMES_STALL_ZOMBIE_PASSES"
echo "tip through #178 (STALL nag install tip#178; Path C early tip#177; ONE-SHOT secrets tab tip#177; NAG Raw tip#176; FALLBACK b2b5fc4 tip159)"
echo "Host: $(hostname) user: $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Status inbox: https://github.com/ilike4movies/hermes-mac-land/issues/1"

_load_mac_hermes_env() {
  local f="${HOME}/.hermes/.env"
  [[ -f "$f" ]] || return 0
  local key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ''|\#*) continue ;;
      LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|HERMES_HOST_SSH_PRIVATE_KEY=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*)
        key="${line%%=*}"
        val="${line#*=}"
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        [[ -z "${!key:-}" ]] && export "$key=$val"
        ;;
    esac
  done < "$f"
}

_preflight_mac_secrets
_open_stall_parallel_pathc
_install_downstream_nag

# ... truncated for push - use full file from disk
exit 0
