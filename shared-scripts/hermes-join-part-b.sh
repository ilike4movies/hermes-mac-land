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
      echo 'Cloud waiters armed; TS_AUTHKEY preferred. Proactive refr