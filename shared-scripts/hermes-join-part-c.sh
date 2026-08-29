_ensure_single_tailscale_up_wait() {
  local login_wait_secs="${1:-$LOGIN_WAIT_SECS}"
  # Tip #131: desired interactive up timeout (0 = forever). Script wait loop still
  # uses login_wait_secs / LOGIN_WAIT_SECS separately.
  local desired_up_timeout="${HERMES_TAILSCALE_UP_TIMEOUT_SECS:-${UP_TIMEOUT_SECS:-0}}"
  # Tip #136: persist last rolled/desired timeout so sibling wait-login processes do not
  # start forever=0 after a tip#135 finite hold-roll (proven remint 184ff33a→e064be30).
  local _persist="${SCRIPT_DIR}/DESIRED_UP_TIMEOUT.txt"
  if [[ -f "$_persist" ]]; then
    local _persisted
    _persisted="$(tr -d ' \r\n' <"$_persist" 2>/dev/null || true)"
    if [[ "${_persisted}" =~ ^[0-9]+$ ]]; then
      # Prefer persist over env when env wants forever (0) but persist has finite roll,
      # OR when persist was explicitly written during this AuthURL hold.
      if (( desired_up_timeout == 0 && _persisted > 0 )); then
        echo "OK tip#136 adopt persisted desired_up_timeout=${_persisted}s (env forever=0; avoid sibling remint)"
        desired_up_timeout="$_persisted"
      elif (( desired_up_timeout > 0 && _persisted > desired_up_timeout )); then
        echo "OK tip#136 adopt persisted desired_up_timeout=${_persisted}s (> env ${desired_up_timeout})"
        desired_up_timeout="$_persisted"
      fi
    fi
  fi
