_resolve_ics_expected_tip() {
  # Tip #167: prefer env, then TIP_PIN, then CURRENT_AUTHURL.md "Tip through **#N**".
  # Tip #168: also CDN-fetch TIP_PIN from main so long-lived wait-login soft-holds
  # pick tip advances without remint/respawn. Returns max(local, CDN); env still wins.
  if [[ -n "${HERMES_AUTHURL_ICS_EXPECTED_TIP:-}" ]]; then
    printf '%s\n' "$HERMES_AUTHURL_ICS_EXPECTED_TIP"
    return 0
  fi
  local best="" pin="" parsed="" cdn_pin="" cdn_md=""
  local pinfile="${SCRIPT_DIR}/TIP_PIN"
  local md="${SCRIPT_DIR}/CURRENT_AUTHURL.md"
  local repo="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
  _tip_max() {
    local a="${1:-}" b="${2:-}"
    if [[ -z "$a" ]]; then printf '%s\n' "$b"; return 0; fi
    if [[ -z "$b" ]]; then printf '%s\n' "$a"; return 0; fi
    if (( 10#$a > 10#$b )); then printf '%s\n' "$a"; else printf '%s\n' "$b"; fi
  }
  if [[ -f "$pinfile" ]]; then
    pin="$(tr -dc '0-9' <"$pinfile" | head -c 8 || true)"
    best="$(_tip_max "$best" "$pin")"
  fi
  if [[ -f "$md" ]] && command -v python3 >/dev/null 2>&1; then
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
    best="$(_tip_max "$best" "$parsed")"
  fi
  # Tip #168 CDN hot-pick (short timeout; never blocks soft-hold long).
  if [[ "${HERMES_TIP_PIN_CDN:-1}" == "1" ]] && command -v curl >/dev/null 2>&1; then
    cdn_pin="$(curl -fsSL --max-time "${HERMES_TIP_PIN_CDN_TIMEOUT_SECS:-3}" \
      "https://raw.githubusercontent.com/${repo}/main/TIP_PIN" 2>/dev/null \
      | tr -dc '0-9' | head -c 8 || true)"
    best="$(_tip_max "$best" "$cdn_pin")"
    if [[ -n "$cdn_pin" && -n "$best" && "$cdn_pin" == "$best" && "${HERMES_TIP_PIN_CDN_SYNC:-1}" == "1" ]]; then
      if [[ -z "$pin" || "$cdn_pin" != "$pin" ]]; then
        printf '%s\n' "$cdn_pin" >"$pinfile" 2>/dev/null || true
      fi
    fi
    if [[ -z "$best" ]]; then
      cdn_md="$(curl -fsSL --max-time "${HERMES_TIP_PIN_CDN_TIMEOUT_SECS:-3}" \
        "https://raw.githubusercontent.com/${repo}/main/CURRENT_AUTHURL.md" 2>/dev/null || true)"
      if [[ -n "$cdn_md" ]] && command -v python3 >/dev/null 2>&1; then
        parsed="$(CURRENT_AUTHURL_MD_TEXT="$cdn_md" python3 - <<'PY'
import os, re
text = os.environ.get("CURRENT_AUTHURL_MD_TEXT") or ""
m = re.search(r"Tip through \*\*#(\d+)\*\*", text)
if not m:
    m = re.search(r"tip through \*\*#(\d+)\*\*", text, re.I)
if not m:
    m = re.search(r"tip through #(\d+)", text, re.I)
if m:
    print(m.group(1))
PY
)" || parsed=""
        best="$(_tip_max "$best" "$parsed")"
      fi
    fi
  fi
  printf '%s\n' "${best:-170}"
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
