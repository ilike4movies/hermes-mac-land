_host_ssh_ready() {
  reload_cloud_secrets
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && return 0
  [[ -s "$HOST_KEY_FILE" ]] && return 0
  return 1
}

wait_for_host_ssh_key() {
  local max="${HERMES_HOST_SSH_WAIT_SECS:-3600}" i=0
  if _host_ssh_ready; then
    echo "OK host SSH key already present"
    return 0
  fi
  echo "== waiting up to ${max}s for HERMES_HOST_SSH_PRIVATE_KEY / $HOST_KEY_FILE =="
  while (( i < max )); do
    reload_cloud_secrets
    if _host_ssh_ready; then
      echo "OK host SSH key arrived after ${i}s"
      return 0
    fi
    if (( i % 60 == 0 )); then
      echo "  t=${i}s still waiting for host SSH / Linear key files (Runtime Secrets)"
    fi
    sleep 15
    i=$((i + 15))
  done
  echo "ERROR: host SSH key not present after ${max}s" >&2
  return 1
}


ts() {
  if [[ -S "$SOCK" ]]; then
    sudo -n tailscale --socket="$SOCK" "$@" 2>/dev/null || tailscale --socket="$SOCK" "$@"
  else
    sudo -n tailscale "$@" 2>/dev/null || tailscale "$@"
  fi
}

backend_state() {
  ts status --json 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get("BackendState") or "")
except Exception:
  print("")
' 2>/dev/null || true
}

_tailscale_up_wait_running() {
  local pid p
  if [[ -f "$TS_UP_PIDFILE" ]]; then
    pid="$(tr -d ' \r\n' < "$TS_UP_PIDFILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  while IFS= read -r p; do
    [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null && return 0
  done < <(pgrep -f 'tailscale.* up ' 2>/dev/null || true)
  return 1
}

