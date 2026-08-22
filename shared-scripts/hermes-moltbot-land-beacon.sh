#!/usr/bin/env bash
# hermes-moltbot-land-beacon.sh - best-effort Linear land STARTED/FAILED beacon
set -u
EVENT="${1:-}"
SOURCE="terminal"
DETAIL=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="${2:-unknown}"; shift 2 ;;
    --detail) DETAIL="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
GH_STATUS_ISSUE="${HERMES_MAC_LAND_STATUS_ISSUE:-1}"
GH_STATUS_REPO="${HERMES_MAC_LAND_STATUS_REPO:-ilike4movies/hermes-mac-land}"
TICKET="${HERMES_LAND_TICKET:-RAL-800}"
HOST="$(hostname 2>/dev/null || echo unknown)"
USER_NAME="$(whoami 2>/dev/null || echo unknown)"
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ "$EVENT" == "started" ]]; then
  MODE="direct .11 (default)"
  [[ "${HERMES_PREFER_DIRECT_HOST:-1}" != "1" ]] && MODE="jump grok-cos-1 first"
  BODY=$(printf '## Mac land STARTED\n\nhost=`%s` user=`%s` at `%s`\nsource=`%s`\nmode=`%s`\n\nRunning tip land path. Expect Host surgical-apply OK next.' "$HOST" "$USER_NAME" "$WHEN" "$SOURCE" "$MODE")
elif [[ "$EVENT" == "failed" ]]; then
  HINT="Probe: ssh BatchMode to ilike4@192.168.1.11 or 100.105.194.96. Post 2026-08-22 host-key: re-run required."
  [[ "${DETAIL:-}" == *preflight* ]] && HINT="Preflight failed — see detail. Post 17:22Z host-key install: re-run land."
  BODY=$(printf '## Mac land FAILED (pre-host)\n\nhost=`%s` user=`%s` at `%s`\nsource=`%s`\ndetail=`%s`\n\n%s' "$HOST" "$USER_NAME" "$WHEN" "$SOURCE" "${DETAIL:-unknown}" "$HINT")
else exit 0; fi
printf '%s\n' "$BODY" >"${HOME}/Desktop/HERMES-MAC-LAND-BEACON.txt" 2>/dev/null || true
command -v gh >/dev/null && gh issue comment "$GH_STATUS_ISSUE" --repo "$GH_STATUS_REPO" --body "$BODY" >/dev/null 2>&1 || true
exit 0
