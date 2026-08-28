_ensure_single_tailscale_up_wait() {
  local login_wait_secs="${1:-$LOGIN_WAIT_SECS}"
  # Proactive AuthURL refresh: if interactive up has been waiting ~45m+ and still
  # NeedsLogin, kill and restart so operators get a fresh approve URL (TTL~1h).
  # Prefer ~45m over ~15m: frequent kills invalidate open approve links mid-click.
  if _tailscale_up_wait_running; then
    local age_s=0 pid
    if [[ -f "$TS_UP_PIDFILE" ]]; then
      pid="$(tr -d ' \r\n' < "$TS_UP_PIDFILE" 2>/dev/null || true)"
    fi
    # Adopt orphan up process into pidfile when missing (post-kill race).
    if [[ -z "${pid:-}" ]] || ! kill -0 "${pid:-}" 2>/dev/null; then
      pid="$(pgrep -f 'tailscale.* up --timeout' 2>/dev/null | head -1 || true)"
      if [[ -n "$pid" ]]; then
        echo "$pid" >"$TS_UP_PIDFILE"
      fi
    fi
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      age_s="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)"
    fi
    if [[ "${age_s:-0}" =~ ^[0-9]+$ ]] && (( age_s >= ${HERMES_TAILSCALE_AUTHURL_REFRESH_SECS:-2700} )); then
      echo "WARN proactive AuthURL refresh — up wait age=${age_s}s >= refresh threshold; restarting"
      if [[ -n "${pid:-}" ]]; then
        sudo kill "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        # also kill child tailscale up if sudo wrapper
        pkill -f "tailscale.* up --timeout" 2>/dev/null || true
        sleep 2
      fi
      rm -f "$TS_UP_PIDFILE" 2>/dev/null || true
    else
      echo "OK tailscale up wait already running (pidfile=$(cat "$TS_UP_PIDFILE" 2>/dev/null || echo none) age_s=${age_s:-?})"
      _refresh_authurl_file
      return 0
    fi
  fi
  exec 9>"$TS_UP_LOCK"
  if ! flock -n 9; then
    echo "OK another process holds tailscale-up lock"
    _refresh_authurl_file
    return 0
  fi
  if _tailscale_up_wait_running; then
    _refresh_authurl_file
    return 0
  fi
  echo "== starting single tailscale up wait (${login_wait_secs}s) =="
  nohup sudo tailscale --socket="$SOCK" up --timeout="${login_wait_secs}s" \
    --hostname="${HERMES_TS_HOSTNAME:-cursor-cloud-hermes}" --accept-routes=true \
    >/tmp/tailscale-up-wait.log 2>&1 &
  echo $! >"$TS_UP_PIDFILE"
  echo "OK started tailscale up wait pid=$(cat "$TS_UP_PIDFILE")"
  sleep 2
  _refresh_authurl_file
}

install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    echo "OK tailscale already installed: $(command -v tailscale)"
    return 0
  fi
  echo "== installing Tailscale =="
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: auto-install only implemented for Linux cloud agents" >&2
    exit 1
  fi
  curl -fsSL https://tailscale.com/install.sh | sh
  command -v tailscale >/dev/null 2>&1
}

ensure_daemon() {
  if pgrep -x tailscaled >/dev/null 2>&1; then
    return 0
  fi
  sudo mkdir -p /var/run/tailscale /var/lib/tailscale /var/cache/tailscale
  if [[ -e /dev/net/tun ]]; then
    sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket="$SOCK" --port=41641 >/tmp/tailscaled.log 2>&1 &
  else
    echo "WARN: /dev/net/tun missing — userspace networking"
    sudo tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket="$SOCK" >/tmp/tailscaled-userspace.log 2>&1 &
  fi
  sleep 2
}

join_tailscale_authkey() {
  echo "== joining Tailscale mesh with TS_AUTHKEY =="
  ts up --authkey="$TS_AUTHKEY" --hostname="${HERMES_TS_HOSTNAME:-cursor-cloud-hermes}" --accept-routes=true
  ts status || true
}

wait_for_running() {
  local max="$1" i=0 st last_st="" last_status_echo=-999
  local status_every="${HERMES_WAIT_LOGIN_STATUS_EVERY_SECS:-60}"
  echo "== waiting up to ${max}s for BackendState=Running (status every ${status_every}s) =="
  while (( i < max )); do
    reload_cloud_secrets
    st="$(backend_state)"
    if [[ "$st" != "$last_st" ]] || (( i - last_status_echo >= status_every )); then
      echo "  t=${i}s BackendState=${st:-unknown} authkey=${TS_AUTHKEY:+set}"
      last_status_echo=$i
      last_st="$st"
      if [[ "$st" == "NeedsLogin" || "$st" == "NoState" || -z "$st" ]]; then
        # Throttle verbose `ts status` (Logged out / AuthURL) — was every 5s → multi-MB logs.
        ts status 2>&1 | sed -n '1,8p' || true
      fi
    fi
    if [[ "$st" == "Running" ]]; then
      return 0
    fi
    if [[ -n "${TS_AUTHKEY:-}" && "$st" != "Running" ]]; then
      echo "  mid-wait TS_AUTHKEY present — joining"
      join_tailscale_authkey || true
    fi
    if [[ "$st" == "NeedsLogin" || "$st" == "NoState" || -z "$st" ]]; then
      _ensure_single_tailscale_up_wait "$max" || true
      _refresh_authurl_file || true
    fi
    sleep 5
    i=$((i + 5))
  done
  echo "ERROR: Tailscale not Running after ${max}s" >&2
  return 1
}

wait_for_jump() {
  local i
  echo "== waiting up to ${WAIT_SECS}s for jump $JUMP_HOST =="
  for ((i=0; i<WAIT_SECS; i+=3)); do
    if ping -c 1 -W 2 "$JUMP_HOST" >/dev/null 2>&1; then
      echo "OK ping $JUMP_HOST after ${i}s"
      return 0
    fi
    if timeout 2 bash -c "echo >/dev/tcp/${JUMP_HOST}/22" 2>/dev/null; then
      echo "OK tcp/22 $JUMP_HOST after ${i}s"
      return 0
    fi
    sleep 3
  done
  echo "ERROR: jump $JUMP_HOST not reachable after ${WAIT_SECS}s" >&2
  return 1
}

reload_cloud_secrets
install_tailscale
ensure_daemon

st_now="$(backend_state)"
if [[ "$ALREADY_UP" -eq 1 || "$st_now" == "Running" ]]; then
  echo "OK Tailscale already Running (or --already-up); skipping join"
elif [[ -n "${TS_AUTHKEY:-}" ]]; then
  join_tailscale_authkey
  wait_for_running "$WAIT_SECS" || true
elif [[ "$WAIT_LOGIN" -eq 1 ]]; then
  echo "== interactive login path (approve AuthURL; single tailscale up) =="
  _ensure_single_tailscale_up_wait "$LOGIN_WAIT_SECS"
  ts status 2>&1 | sed -n '1,12p' || true
  wait_for_running "$LOGIN_WAIT_SECS"
else
  echo "ERROR: TS_AUTHKEY unset and not Running. Re-run with TS_AUTHKEY=... or --wait-login / --already-up" >&2
  exit 2
fi

# Downstream-only prefers direct host SSH; do not abort the closed-loop path
# if jump ping fails after Tailscale Running (routes may still reach .11).
if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" != "1" ]]; then
  if ! wait_for_jump; then
    echo "WARN jump not reachable — continuing downstream-only (direct host SSH)"
  fi
else
  wait_for_jump
fi

# When surgical land is disabled (stalled-canary recovery), run dispatcher
# downstream instead of via-ssh tip land. Still needs host SSH + Linear keys.
if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" != "1" ]]; then
  echo "== HERMES_AUTO_SURGICAL_LAND=0 — dispatcher downstream (not surgical land) =="
  wait_for_host_ssh_key || {
    echo "ERROR: cannot run downstream without HERMES_HOST_SSH_PRIVATE_KEY" >&2
    exit 1
  }
  ds="$SCRIPT_DIR/hermes-dispatcher-downstream.sh"
  if [[ ! -x "$ds" ]]; then
    echo "ERROR: missing $ds" >&2
    exit 1
  fi
  export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
  export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
  export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
  export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
  export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
  # Ooterverse override env must not poison downstream preflight once TS+SSH ready.
  export COMPOSER_REPO_URL="${HERMES_DOWNSTREAM_COMPOSER_REPO_URL:-github.com/ilike4movies/hermes-mac-land}"
  bash "$ds"
  echo "OK cloud-tailscale-join-and-apply finished (downstream-only)"
  exit 0
fi

export HERMES_JUMP_SSH="$JUMP_SSH"
bash "$SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"

echo "OK cloud-tailscale-join-and-apply finished (expect OK INTERRUPT_LABEL hermes-now)"
exit 0
