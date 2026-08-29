_refresh_authurl_file() {
  local url authfile="${SCRIPT_DIR}/CURRENT_AUTHURL.txt"
  local lastfile="${SCRIPT_DIR}/LAST_POSTED_AUTHURL.txt"
  local gh_repo="${HERMES_STATUS_GITHUB_REPO:-ilike4movies/hermes-mac-land}"
  local gh_issue="${HERMES_STATUS_GITHUB_ISSUE:-1}"
  local linear_ticket="${HERMES_AUTHURL_LINEAR_ISSUE:-RAL-823}"
  reload_cloud_secrets || true
  url="$(ts status 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[a-z0-9]+' | head -1 || true)"
  [[ -n "$url" ]] || return 0
  local pending="${SCRIPT_DIR}/PENDING_AUTHURL_TIP.txt"
  local auth_changed=0 pending_stale=0
  if [[ ! -f "$authfile" ]] || ! grep -qF "$url" "$authfile" 2>/dev/null; then
    auth_changed=1
  fi
  if [[ ! -f "$pending" ]] || ! grep -qF "$url" "$pending" 2>/dev/null; then
    pending_stale=1
  fi
  if [[ "$auth_changed" == "1" ]]; then
    {
      printf '%s\n' "$url"
      printf 'ACTIVE — approve now (%s).\n' "$(date -u +%FT%TZ)"
      echo 'Cloud waiters armed; TS_AUTHKEY preferred. Proactive refresh before prior TTL.'
    } >"$authfile"
    echo "APPROVE_THIS_URL=$url"
  fi
  # Tip #134: soft-hold ICS rewrite when calendar window is expired/near-expiry
  # while the same AuthURL is still advertised (avoids mid-approve calendar miss).
  local ics_need_refresh=0
  local ics_local="${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics"
  if [[ ! -f "$ics_local" ]]; then
    ics_need_refresh=1
  elif command -v python3 >/dev/null 2>&1; then
    if ! ICS_PATH="$ics_local" HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS="${HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS:-1800}" python3 - <<'PY'
import os, re
from datetime import datetime, timezone
path = os.environ["ICS_PATH"]
remain = int(os.environ.get("HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS") or "1800")
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    raise SystemExit(1)
m = re.search(r"^DTEND:([0-9]{8}T[0-9]{6}Z)$", text, re.M)
if not m:
    raise SystemExit(1)
end = datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
raise SystemExit(0 if (end - now).total_seconds() > remain else 1)
PY
    then
      ics_need_refresh=1
    fi
  fi
  # Keep PENDING + local ICS aligned even if CURRENT was written out-of-band
  # (hard wipe / agent MCP) so cloud agents do not read a stale AuthURL marker.
  # Tip #134: also rewrite when ICS hold window is nearly expired (soft AuthURL hold).
  if [[ "$auth_changed" == "1" || "$pending_stale" == "1" || "$ics_need_refresh" == "1" ]]; then
    {
      printf '%s\n' "$url"
      printf 'refreshed=%s\n' "$(date -u +%FT%TZ)"
    } >"$pending"
    if command -v python3 >/dev/null 2>&1; then
      AUTHURL_ICS_URL="$url" HERMES_AUTHURL_ICS_HOLD_HOURS="${HERMES_AUTHURL_ICS_HOLD_HOURS:-6}" python3 - <<'ICS' >"${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics" 2>/dev/null || true
import os
from datetime import datetime, timedelta, timezone
url = os.environ["AUTHURL_ICS_URL"]
suffix = url.rstrip("/").rsplit("/", 1)[-1][:12]
now = datetime.now(timezone.utc)
dt = now.strftime("%Y%m%dT%H%M%SZ")
hold_h = max(1, int(os.environ.get("HERMES_AUTHURL_ICS_HOLD_HOURS") or "6"))
end = (now + timedelta(hours=hold_h)).strftime("%Y%m%dT%H%M%SZ")
uid = f"hermes-authurl-{suffix}-{int(now.timestamp())}@hermes-mac-land"
print(f"""BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Hermes Mac Land//AuthURL Wake//EN
CALSCALE:GREGORIAN
METHOD:REQUEST
BEGIN:VEVENT
UID:{uid}
DTSTAMP:{dt}
DTSTART:{dt}
DTEND:{end}
SUMMARY:ACTION: Approve Hermes Tailscale AuthURL {suffix}
DESCRIPTION:Approve NOW: {url}\\nThen add Runtime Secrets HERMES_HOST_SSH_PRIVATE_KEY + LINEAR_API_KEY.\\nOr Mac ONE-SHOT from hermes-mac-land tip.
LOCATION:{url}
URL:{url}
STATUS:CONFIRMED
SEQUENCE:0
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Approve Tailscale AuthURL {suffix} NOW
TRIGGER:-PT0S
END:VALARM
END:VEVENT
END:VCALENDAR""")
ICS
    fi
  fi
  # Tip #134: when AuthURL is unchanged but ICS hold expired, still refresh tip ICS
  # (does not remint AuthURL; throttled by local rewrite above).
  if [[ "$ics_need_refresh" == "1" && "$auth_changed" != "1" && "${HERMES_AUTHURL_TIP_ICS:-1}" == "1" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      local tip_tok="${GITHUB_TOKEN:-${GH_TOKEN:-${HERMES_GH_WORKFLOW_PAT:-}}}"
      local tip_owner tip_name gh_repo="${HERMES_STATUS_GITHUB_REPO:-ilike4movies/hermes-mac-land}"
      tip_owner="${gh_repo%%/*}"
      tip_name="${gh_repo#*/}"
      local ics_path="HERMES-APPROVE-TAILSCALE.ics" ics_body ics_sha ics_b64 ics_api i