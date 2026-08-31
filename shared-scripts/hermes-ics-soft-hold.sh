#!/bin/bash
# Tip #183: after tip-stale/TTL ICS rewrite, stamp ICS_SOFT_HOLD_PUSH_NEEDED so agents push hermes-mac-land ICS+CURRENT+LAST (tip#182 dir pick).
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
_BODY="$(mktemp)"
curl -fsSL --max-time 10 \
  "https://raw.githubusercontent.com/${REPO}/0d34461565d0927222c77f83924de12291444d94/shared-scripts/hermes-ics-soft-hold.sh" \
  -o "$_BODY"
_OUT="$(mktemp)"
set +e
HERMES_ICS_SOFT_HOLD_DIR="$SCRIPT_DIR" bash "$_BODY" | tee "$_OUT"
_rc=${PIPESTATUS[0]}
set -e
# Tip #183: stamp push-needed when soft-hold rewrote ICS (agents must push hermes-mac-land)
if grep -q 'ICS_SOFT_HOLD_REWRITE=1' "$_OUT" 2>/dev/null; then
  echo "1" > "$SCRIPT_DIR/ICS_SOFT_HOLD_PUSH_NEEDED"
  echo "OK tip #183 stamped ICS_SOFT_HOLD_PUSH_NEEDED under $SCRIPT_DIR — push HERMES-APPROVE-TAILSCALE.ics + CURRENT_AUTHURL.md + LAST_ICS_SOFT_HOLD.json to main"
fi
rm -f "$_BODY" "$_OUT"
exit "$_rc"
