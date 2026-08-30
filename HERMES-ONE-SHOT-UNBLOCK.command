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
echo "zombie=$HERMES_STALL_ZOMBIE zombie_passes=$HERMES_STALL_ZOMBIE_PASSES stall_recovery=$HERMES_STAL