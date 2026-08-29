_resolve_ics_expected_tip() {
  # Tip #167: prefer env, then TIP_PIN, then CURRENT_AUTHURL.md "Tip through **#N**", else 167.
  # Stops tip-stale soft-hold from needing a join-part-b tip bump on every tip advance.
  if [[ -n "${HERMES_AUTHURL_ICS_EXPECTED_TIP:-}" ]]; then
    printf '%s\n' "$HERMES_AUTHURL_ICS_EXPECTED_TIP"
    return 0
  fi
  local pinfile="${SCRIPT_DIR}/TIP_PIN"
  if [[ -f "$pinfile" ]]; then
    local pin
    pin="$(tr -dc '0-9' <"$pinfile" | head -c 8 || true)"
    if [[ -n "$pin" ]]; then
      printf '%s\n' "$pin"
      return 0
    fi
  fi
  local md="${SCRIPT_DIR}/CURRENT_AUTHURL.md"
  if [[ -f "$md" ]] && command -v python3 >/dev/null 2>&1; then
    local parsed
    parsed="$(python3 - "$md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r"Tip through \*\*#(\d+)\*\*", text)
if not m:
    m = re.search(r"tip through \*\*#(\d+)\*\*", text, re.I)
if not m:
    m = re.search(r"tip through #(\d+)", text, re.I)
if m:
    print(m.group(1))
    raise SystemExit(0)
raise SystemExit(1)
PY
)" || parsed=""
    if [[ -n "$parsed" ]]; then
      printf '%s\n' "$parsed"
      return 0
    fi
  fi
  printf '%s\n' "167"
}

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
  # Tip #166: also rewrite SUMMARY/DESCRIPTION in-place when tip pin is stale even if
  # DTEND remain_s is still healthy (no AuthURL remint; preserve UID/DTEND).
  local ics_need_refresh=0
  local ics_tip_stale=0
  local ics_local="${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics"
  # Tip #167: resolve expected tip from env / TIP_PIN / CURRENT_AUTHURL.md (default 167).
  local ics_expected_tip
  ics_expected_tip="$(_resolve_ics_expected_tip)"
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
    if ! ICS_PATH="$ics_local" HERMES_AUTHURL_ICS_EXPECTED_TIP="$ics_expected_tip" python3 - <<'PY'
import os, re
path = os.environ["ICS_PATH"]
expect = int(os.environ.get("HERMES_AUTHURL_ICS_EXPECTED_TIP") or "167")
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    raise SystemExit(1)
m = re.search(r"^SUMMARY:.*\(tip #(\d+)\)", text, re.M)
if not m:
    raise SystemExit(1)
raise SystemExit(0 if int(m.group(1)) >= expect else 1)
PY
    then
      ics_tip_stale=1
    fi
  fi
  # Tip #166: tip-pin soft-hold — rewrite SUMMARY/DESCRIPTION/VALARM only; keep DTEND/UID/URL.
  if [[ "$ics_tip_stale" == "1" && "$ics_need_refresh" != "1" && "$auth_changed" != "1" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      AUTHURL_ICS_URL="$url" ICS_PATH="$ics_local" HERMES_AUTHURL_ICS_EXPECTED_TIP="$ics_expected_tip" python3 - <<'PY' 2>/dev/null || true
import os, re
path = os.environ