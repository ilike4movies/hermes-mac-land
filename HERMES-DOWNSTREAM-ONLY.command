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

_preflight_mac_secrets() {
  _load_mac_hermes_env || true
  if [[ -z "${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}" ]]; then
    echo ""
    echo "FAILED: LINEAR_API_KEY (or LINEAR_API_TOKEN) missing — required for fail-closed DISPATCH-NOW."
    echo " fix: add LINEAR_API_KEY=... to ~/.hermes/.env, then Right-click → Open this file again."
    osascript -e 'display notification "Add LINEAR_API_KEY to ~/.hermes/.env" with title "Hermes DOWNSTREAM preflight FAILED" sound name "Basso"' 2>/dev/null || true
    read -r -p "Press Enter to close…" _
    exit 1
  fi
  if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
    echo "WARN: HERMES_HOST_SSH_PRIVATE_KEY not loaded — ensure ~/.hermes/.env has the host key or SSH agent works."
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

_open_stall_parallel_pathc() {
  if [[ "${HERMES_STALL_OPEN_PATHC_EARLY:-1}" != "1" ]]; then
    echo "SKIP STALL parallel Path C (HERMES_STALL_OPEN_PATHC_EARLY=0)"
    return 0
  fi
  local REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
  local WEBUI_NEW="https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml"
  local WEBUI_RAW="https://github.com/${REPO}/raw/main/ci/downstream-stall.yml"
  local SECRETS_UI="https://github.com/${REPO}/settings/secrets/actions"
  local DROPBOX_WAKE="${HERMES_DROPBOX_WAKE_URL:-https://www.dropbox.com/scl/fi/t8p9b7qqnrrbrijhn1r1j/WAKE-1d0d8050-tip169.txt?rlkey=4p6zu480sotpw7lb34rjkbxli&dl=1}"
  local ZAPIER_GH="${HERMES_ZAPIER_GH_RECONNECT_URL:-https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336}"
  local ZAPIER_CAL="${HERMES_ZAPIER_CAL_RECONNECT_URL:-https://mcp.zapier.com/api/v1/connect-auth/GoogleCalendarCLIAPI?accountId=12547336&connectionId=55516487}"
  echo ""
  echo "=== Parallel: Path C + Tailscale approve (tip #177) while STALL runs ==="
  open "https://login.tailscale.com/admin/machines" 2>/dev/null || true
  local auth=""
  local f="/tmp/hermes-stall-current-authurl-$$.md"
  if curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/CURRENT_AUTHURL.md" -o "$f" 2>/dev/null; then
    auth=$(grep -Eo 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' "$f" | head -1 || true)
  fi
  rm -f "$f"
  [[ -n "$auth" ]] && open "$auth" 2>/dev/null || true
  open "$WEBUI_NEW" 2>/dev/null || true
  open "$WEBUI_RAW" 2>/dev/null || true
  open "$SECRETS_UI" 2>/dev/null || true
  open "$DROPBOX_WAKE" 2>/dev/null || true
  open "$ZAPIER_GH" 2>/dev/null || true
  open "$ZAPIER_CAL" 2>/dev/null || true
}

_install_downstream_nag() {
  if [[ "${HERMES_STALL_INSTALL_NAG:-1}" != "1" ]]; then
    echo "SKIP downstream nag install (HERMES_STALL_INSTALL_NAG=0)"
    return 0
  fi
  local REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
  local PIN="${HERMES_MAC_LAND_PIN:-main}"
  echo ""
  echo "=== Install Downstream nag LaunchAgent (5 min + auto ONE-SHOT until DONE) ==="
  local NAG="/tmp/hermes-install-downstream-nag-only-$$.command"
  local url
  rm -f "$NAG"
  for url in \
    "https://raw.githubusercontent.com/${REPO}/${PIN}/HERMES-INSTALL-DOWNSTREAM-NAG.command" \
    "https://raw.githubusercontent.com/${REPO}/main/HERMES-INSTALL-DOWNSTREAM-NAG.command"
  do
    if curl -fsSL "$url" -o "$NAG" \
      && grep -q 'com.hermes.downstream-nag' "$NAG" 2>/dev/null \
      && grep -q '_machine_downstream_done' "$NAG" 2>/dev/null \
      && grep -q 'Downstream DONE @' "$NAG" 2>/dev/null; then
      chmod +x "$NAG"
      if HERMES_NAG_NONINTERACTIVE=1 bash "$NAG"; then
        echo "OK downstream nag installed/refreshed (tip #178)"
        rm -f "$NAG"
        return 0
      fi
      echo "WARN nag installer exited non-zero — continuing DOWNSTREAM"
      rm -f "$NAG"
      return 0
    fi
    rm -f "$NAG"
  done
  echo "WARN could not fetch HERMES-INSTALL-DOWNSTREAM-NAG.command — continuing DOWNSTREAM"
  return 0
}

_preflight_mac_secrets
_open_stall_parallel_pathc
_install_downstream_nag

osascript -e 'display notification "Running stall-class downstream gates on .11…" with title "Hermes DOWNSTREAM" sound name "Glass"' 2>/dev/null || true
xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true

SCRIPT="/tmp/hermes-dispatcher-downstream-fetched-$$.sh"
ONCE="/tmp/hermes-cloud-run-downstream-once-$$.sh"
rm -f "$SCRIPT" "$ONCE"
FETCHED=""
DOWNSTREAM_PIN="${HERMES_DOWNSTREAM_PIN:-}"
_is_good_once() {
  local f="$1"
  grep -q 'Tip #142' "$f" 2>/dev/null \
    && grep -q 'hermes-dispatcher-downstream.sh' "$f" 2>/dev/null \
    && grep -q 'flock' "$f" 2>/dev/null
}
_is_good_downstream() {
  local f="$1"
  if grep -q 'ONE-SHOT safe entrypoint' "$f" 2>/dev/null \
     && grep -q 'hermes-dispatcher-part-a.sh' "$f" 2>/dev/null \
     && grep -q 'raw.githubusercontent.com' "$f" 2>/dev/null \
     && grep -q '_parts_integrity_ok' "$f" 2>/dev/null \
     && grep -qE 'b2b5fc4|HERMES_STATUS_GITHUB_TOKEN|Downstream DONE beacon did not post' "$f" 2>/dev/null; then
    return 0
  fi
  if grep -q 'RAL-793 run inspect' "$f" 2>/dev/null \
     && grep -q 'stack-apply' "$f" 2>/dev/null \
     && grep -q 'DISPATCH-NOW' "$f" 2>/dev/null \
     && grep -q 'RAL-634 starvation verify' "$f" 2>/dev/null \
     && grep -q 'HERMES_GH_BEACON_TIMEOUT_SECS' "$f" 2>/dev/null \
     && grep -q 'STALL_DISPATCH_PASSES' "$f" 2>/dev/null \
     && grep -q 'WAIT_INVENTORY' "$f" 2>/dev/null \
     && grep -q 'fail-closed' "$f" 2>/dev/null \
     && grep -qE 'b2b5fc4|HERMES_STATUS_GITHUB_TOKEN|Downstream DONE beacon did not post' "$f" 2>/dev/null; then
    return 0
  fi
  return 1
}
for url in \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/shared-scripts/hermes-cloud-run-downstream-once.sh" \
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-run-downstream-once.sh"
do
  echo "Trying once launcher: $url"
  if curl -fsSL "$url" -o "$ONCE" && _is_good_once "$ONCE"; then
    chmod +x "$ONCE" 2>/dev/null || true
    echo "OK tip#148 using once launcher: $url"
    set +e
    bash "$ONCE"
    rc=$?
    set -e
    rm -f "$ONCE"
    if [[ "$rc" -eq 0 ]]; then
      echo "OK downstream gates finished for run $HERMES_RUN_ID (once)"
      echo "NEXT: confirm Linear inventory evidence (not WORK-PACKET-DONE alone)"
      echo " watch GitHub issue #1 for Downstream DONE receipt"
      osascript -e 'display notification "Downstream OK. Watch Linear + GitHub #1." with title "Hermes DOWNSTREAM OK" sound name "Hero"' 2>/dev/null || true
      say "Hermes downstream complete. Watch Linear for inventory evidence." 2>/dev/null || true
      read -r -p "Press Enter to close…" _
      exit 0
    fi
    echo "WARN once launcher exited $rc — falling back to dispatcher entrypoint"
    break
  fi
  rm -f "$ONCE"
done
urls=(
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}/shared-scripts/hermes-dispatcher-downstream.sh"
  "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh"
)
if [[ -n "$DOWNSTREAM_PIN" ]]; then
  urls+=("https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${DOWNSTREAM_PIN}/shared-scripts/hermes-dispatcher-downstream.sh")
fi
for url in "${urls[@]}"; do
  echo "Trying fetch: $url"
  if curl -fsSL "$url" -o "$SCRIPT"; then
    if _is_good_downstream "$SCRIPT"; then
      FETCHED="$url"
      break
    fi
    rm -f "$SCRIPT"
  fi
done

if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
  echo "FAILED: could not download hermes-dispatcher-downstream.sh (need inspect + stack-apply + dual-dispatch + inventory-wait + GitHub beacon chain)"
  osascript -e 'display notification "Download FAILED." with title "Hermes DOWNSTREAM FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 1
fi

chmod +x "$SCRIPT" 2>/dev/null || true
echo "OK fetched from: $FETCHED"
if bash "$SCRIPT"; then
  echo "OK downstream gates finished for run $HERMES_RUN_ID"
  echo "NEXT: confirm Linear inventory evidence (not WORK-PACKET-DONE alone)"
  echo " watch GitHub issue #1 for Downstream DONE receipt"
  osascript -e 'display notification "Downstream OK. Watch Linear + GitHub #1." with title "Hermes DOWNSTREAM OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes downstream complete. Watch Linear for inventory evidence." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi
RC=$?
echo "FAILED: downstream exited $RC"
osascript -e 'display notification "Downstream FAILED. See Terminal." with title "Hermes DOWNSTREAM FAILED" sound name "Basso"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit "$RC"
