_ensure_single_tailscale_up_wait() {
  local login_wait_secs="${1:-$LOGIN_WAIT_SECS}"
  # Proactive AuthURL refresh: if interactive up has been waiting ~45m+ and still
  # NeedsLogin, kill and restart so operators get a fresh approve URL (TTL~1h).
  # Prefer ~45m over ~15m: frequent kills invalidate open approve links mid-click.
  #
  # Tip #130: when a *short* up timeout (< desired LOGIN_WAIT_SECS, e.g. leftover
  # 3600s after tip #129 raised the default to 14400) is near expiry, do a
  # *controlled* soft upgrade to the longer timeout instead of #125 soft-skip
  # holding until surprise remint at short-timeout death.
  local _do_restart=0 _upgrade_short=0 _hard=0 age_s=0 pid="" _up_timeout="" _remain=""
  if _tailscale_up_wait_running; then
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
      # Parse --timeout=Ns from the live up cmdline (sudo parent or child).
      _up_timeout="$(ps -o args= -p "$pid" 2>/dev/null | sed -n 's/.*--timeout=\([0-9][0-9]*\)s.*/\1/p' | head -1 || true)"
      if [[ -z "${_up_timeout}" ]]; then
        _up_timeout="$(ps -eo args= 2>/dev/null | sed -n 's/.*tailscale.* up --timeout=\([0-9][0-9]*\)s.*/\1/p' | head -1 || true)"
      fi
    fi
    if [[ ! "${age_s:-0}" =~ ^[0-9]+$ ]]; then age_s=0; fi

    # Tip #130 pre-expiry short→long timeout upgrade (bypasses soft-skip).
    if [[ "${HERMES_TAILSCALE_UP_UPGRADE_SHORT:-1}" == "1" ]] \
      && [[ "${_up_timeout:-}" =~ ^[0-9]+$ ]] \
      && (( _up_timeout < login_wait_secs )); then
      _remain=$(( _up_timeout - age_s ))
      local lead="${HERMES_TAILSCALE_UP_UPGRADE_LEAD_SECS:-900}"
      local refresh="${HERMES_TAILSCALE_AUTHURL_REFRESH_SECS:-2700}"
      if (( _remain <= lead )) || (( age_s >= refresh )); then
        _do_restart=1
        _upgrade_short=1
        echo "WARN tip#130 controlled up-timeout upgrade ${_up_timeout}s → ${login_wait_secs}s (age_s=${age_s} remain_s=${_remain} lead_s=${lead})"
        echo "upgrade=$(date -u +%FT%TZ) from=${_up_timeout} to=${login_wait_secs} age_s=${age_s} remain_s=${_remain}" \
          >>"${SCRIPT_DIR}/LAST_UP_TIMEOUT_UPGRADE.txt" 2>/dev/null || true
        # Soft remint may keep or change AuthURL — flag MCP surface so agents re-check.
        echo "tip130_upgrade=$(date -u +%FT%TZ) from=${_up_timeout} to=${login_wait_secs}" \
          >"${SCRIPT_DIR}/AUTHURL_MCP_SURFACE_NEEDED.txt" 2>/dev/null || true
      fi
    fi

    if [[ "$_do_restart" != "1" ]] && (( age_s >= ${HERMES_TAILSCALE_AUTHURL_REFRESH_SECS:-2700} )); then
      # Tip #125: if soft mode and status still advertises a live AuthURL, do NOT kill/re-up.
      # Soft re-up often mints a NEW login URL and invalidates Gmail/RAL-823/Notion/tip links
      # mid-approve (seen 1f410a53 → 7a69b1a0 @ ~21:15Z). Prefer keeping the live AuthURL
      # until Tailscale stops advertising it (or HARD / FORCE_REFRESH).
      # Tip #130 short-timeout upgrade (above) intentionally bypasses this soft-skip.
      _live_authurl=""
      _live_authurl="$(sudo tailscale --socket="${SOCK:-/var/run/tailscale/tailscaled.sock}" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print((d.get("AuthURL") or "").strip())
except Exception:
  print("")' 2>/dev/null || true)"
      if [[ "${HERMES_AUTHURL_HARD_ON_REFRESH:-0}" != "1" && "${HERMES_AUTHURL_FORCE_REFRESH:-0}" != "1" && -n "${_live_authurl}" ]]; then
        # Tip #128: throttle soft-skip OK echo (was every wait-login poll ~5–8s → log spam).
        local every="${HERMES_WAIT_LOGIN_STATUS_EVERY_SECS:-60}" stamp="$SCRIPT_DIR/LAST_UP_OK_ECHO.at" now
        now="$(date +%s)"
        if [[ ! -f "$stamp" ]] || (( now - $(cat "$stamp" 2>/dev/null || echo 0) >= every )); then
          echo "OK AuthURL refresh mode=SOFT skip — live AuthURL still advertised (age_s=${age_s}; set HERMES_AUTHURL_FORCE_REFRESH=1 or HARD=1 to remint)"
          echo "OK tailscale up wait already running (pidfile=$(cat "$TS_UP_PIDFILE" 2>/dev/null || echo none) age_s=${age_s:-?} live_authurl=yes)"
          echo "$now" >"$stamp"
        fi
        _refresh_authurl_file
        return 0
      fi
      _do_restart=1
      echo "WARN proactive AuthURL refresh — up wait age=${age_s}s >= refresh threshold; restarting"
    fi

    if [[ "$_do_restart" == "1" ]]; then
      # Soft kill+re-up often reissues the SAME AuthURL — that is desirable while an
      # operator still has Gmail/RAL-823/Notion/tip links open. Hard state wipe mints a
      # NEW AuthURL and invalidates every surface mid-approve.
      #
      # Tip #123: default SOFT keep-alive (HERMES_AUTHURL_HARD_ON_REFRESH=0).
      # Tip #125: soft skips remint while AuthURL still advertised (above).
      # Tip #130: short→long timeout upgrade bypasses soft-skip near short expiry.
      # Do NOT force hard merely because GH_TOKEN_INVALID / AUTHURL_MCP_SURFACE_NEEDED —
      # those mean tip/beacon must go via MCP, not that the AuthURL is dead.
      # Opt in to hard wipe: HERMES_AUTHURL_HARD_ON_REFRESH=1 (or restart-authurl-hard.sh).
      # Force soft remint: HERMES_AUTHURL_FORCE_REFRESH=1.
      if [[ "${HERMES_AUTHURL_HARD_ON_REFRESH:-0}" == "1" ]]; then _hard=1; fi
      if [[ "$_upgrade_short" == "1" ]]; then
        echo "OK AuthURL refresh mode=SOFT upgrade (tip#130 short-timeout → ${login_wait_secs}s)"
      elif [[ "$_hard" == "1" ]]; then
        echo "WARN AuthURL refresh mode=HARD (HERMES_AUTHURL_HARD_ON_REFRESH=1)"
      else
        echo "OK AuthURL refresh mode=SOFT remint (no live AuthURL or FORCE_REFRESH=1; set HERMES_AUTHURL_HARD_ON_REFRESH=1 to wipe)"
      fi
      if [[ -n "${pid:-}" ]]; then
        sudo kill "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        # Kill only interactive up waiters (avoid pkill -f self-match on wait-login).
        # Prefer sudo kill — interactive `tailscale up` is often root-owned; os.kill fails
        # with EPERM and leaves orphans that force a second up (AuthURL churn).
        python3 - <<'PY' 2>/dev/null || true
import subprocess, time
out = subprocess.check_output(["ps", "-eo", "pid,args"], text=True)
for line in out.splitlines():
    args = line.split(None, 1)[1] if " " in line else ""
    is_up = ("up --timeout" in args) and (
        args.startswith("sudo tailscale")
        or args.startswith("tailscale ")
        or args.startswith("/usr/bin/tailscale")
    )
    if is_up:
        pid = line.split()[0]
        subprocess.run(["sudo", "kill", "-TERM", pid], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["kill", "-TERM", pid], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)
PY
        sleep 1
      fi
      rm -f "$TS_UP_PIDFILE" 2>/dev/null || true
      if [[ "$_hard" == "1" ]]; then
        local _state="${HERMES_TAILSCALED_STATE:-/var/lib/tailscale/tailscaled.state}"
        echo "WARN hard AuthURL rotate on refresh — wiping ${_state} (soft often reissues same URL)"
        sudo tailscale --socket="${SOCK:-/var/run/tailscale/tailscaled.sock}" logout 2>/dev/null || true
        sudo rm -fv "$_state" "${_state}.tmp" 2>/dev/null || true
        # Leave AUTHURL_MCP_SURFACE_NEEDED so agent tip/beacon still surfaces the NEW URL.
        echo "hard_refresh=$(date -u +%FT%TZ) age_s=${age_s}" >>"${SCRIPT_DIR}/LAST_HARD_AUTHURL_REFRESH.txt" 2>/dev/null || true
      fi
    else
      # Throttle OK chatter (was every 5s → multi-MB wait-login.log).
      local every="${HERMES_WAIT_LOGIN_STATUS_EVERY_SECS:-60}" stamp="$SCRIPT_DIR/LAST_UP_OK_ECHO.at" now
      now="$(date +%s)"
      if [[ ! -f "$stamp" ]] || (( now - $(cat "$stamp" 2>/dev/null || echo 0) >= every )); then
        if [[ -n "${_up_timeout}" ]] && (( _up_timeout < login_wait_secs )); then
          echo "OK tip#130 short up still young (timeout=${_up_timeout}s desired=${login_wait_secs}s age_s=${age_s:-?} remain_s=$((_up_timeout - age_s)); upgrade near expiry)"
        fi
        echo "OK tailscale up wait already running (pidfile=$(cat "$TS_UP_PIDFILE" 2>/dev/null || echo none) age_s=${age_s:-?})"
        echo "$now" >"$stamp"
      fi
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
  # Tip #129: default login_wait_secs is 14400 (4h) via HERMES_TAILSCALE_LOGIN_WAIT_SECS.
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
