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
end = datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ").re