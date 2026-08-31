#!/bin/bash
# Tip #182: hermes-ics-soft-hold.sh - prefer hermes-mac-land over cloud-apply
# Thin tip182 wrapper: dir-pick + exec tip181 soft-hold body from tip CDN pin.
set -euo pipefail
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
if [[ -n "${HERMES_ICS_SOFT_HOLD_DIR:-}" ]]; then
  SCRIPT_DIR="$HERMES_ICS_SOFT_HOLD_DIR"
else
  # Tip #182: prefer hermes-mac-land (git tip agents push from) over cloud-apply
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
        best="$d"; best_tip="$t"
      elif (( 10#$t == 10#$best_tip )) && [[ "$d" == /tmp/hermes-mac-land ]]; then
        best="$d"
      fi
    fi
  done
  [[ -n "$best" ]] && SCRIPT_DIR="$best"
fi
export HERMES_ICS_SOFT_HOLD_DIR="$SCRIPT_DIR"
# Run tip181 soft-hold body (ICS rewrite) with tip182 dir already selected.
_BODY="$(mktemp)"
curl -fsSL --max-time 10 \
  "https://raw.githubusercontent.com/${REPO}/0d34461565d0927222c77f83924de12291444d94/shared-scripts/hermes-ics-soft-hold.sh" \
  -o "$_BODY"
# Force SCRIPT_DIR via env so tip181 body does not re-pick cloud-apply first.
HERMES_ICS_SOFT_HOLD_DIR="$SCRIPT_DIR" bash "$_BODY"
