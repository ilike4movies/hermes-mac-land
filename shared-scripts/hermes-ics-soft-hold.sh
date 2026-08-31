#!/bin/bash
# hermes-ics-soft-hold.sh — tip #168/#169/#174
# Standalone CDN TIP_PIN hot-pick + ICS tip-stale/TTL soft-hold.
# Safe to curl|bash from cloud agents/timers without reminting AuthURL or
# respawning wait-login. Preserves UID/DTEND/URL on tip-stale rewrite.
# Tip #174: writes LAST_ICS_SOFT_HOLD.json + stamps CURRENT_AUTHURL.md ICS hold.
set -euo pipefail
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
if [[ -n "${HERMES_ICS_SOFT_HOLD_DIR:-}" ]]; then
  SCRIPT_DIR="$HERMES_ICS_SOFT_HOLD_DIR"
else
  # Tip #182: prefer hermes-mac-land (git tip agents push from) over cloud-apply
  # mirror. Old order broke on first hit in /tmp/hermes-cloud-apply — tip-stale
  # rewrites landed in a stale mirror and never reached main until manual copy.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  best=""; best_tip=-1
  for d in /tmp/hermes-mac-land /tmp/hermes-cloud-apply "$SCRIPT_DIR" "$(dirname "$SCRIPT_DIR")"; do
    [[ -z "$d" || ! -d "$d" ]] && continue
    if [[ -f "$d/HERMES-APPROVE-TAILSCALE.ics" || -f "$d/TIP_PIN" ]]; then
      t=0
      if [[ -f "$d/TIP_PIN" ]]; then
        t="$(tr -dc '0-9' <"$d/TIP_PIN" | head -c 8 || true)"
        t="${t:-0}"
      fi
      if [[ -z "$best" ]] || (( 10#$t > 10#$best_tip )); then
        best="$d"
        best_tip="$t"
      elif (( 10#$t == 10#$best_tip )) && [[ "$d" == /tmp/hermes-mac-land ]]; then
        best="$d"
      fi
    fi
  done
  [[ -n "$best" ]] && SCRIPT_DIR="$best"
fi
