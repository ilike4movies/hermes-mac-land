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
  # Proactive AuthURL refresh: if interactive up has been waiting ~45m+ and still
  # NeedsLogin, kill and restart so operators get a fresh approve URL (TTL~1h).
  # Prefer ~45m over ~15m: frequent kills invalidate open approve links mid-click.
  #
  # Tip #130/#131: when a *finite* up timeout is shorter than desired (desired 0=
  # forever, or leftover 3600/14400), near that finite expiry do a *controlled*
  # soft upgrade instead of #125 soft-skip holding until surprise remint.
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

    # Tip #130/#131 pre-expiry finite→desired up-timeout upgrade (bypasses soft-skip).
    # desired 0 = forever: any finite up_timeout is "short". Trigger ONLY near the
    # finite up's own expiry (remain<=lead) so we do not remint a healthy 14400s
    # up at the 45m soft-refresh age while migrating to forever.
    _is_short=0
    if [[ "${_up_timeout:-}" =~ ^[0-9]+$ ]]; then
      if (( desired_up_timeout == 0 )); then
        if (( _up_timeout > 0 )); then _is_short=1; fi
      elif (( _up_timeout < desired_up_timeout )); then
        _is_short=1
      fi
    fi
    if [[ "${HERMES_TAILSCALE_UP_UPGRADE_SHORT:-1}" == "1" && "$_is_short" == "1" ]]; then
      _remain=$(( _up_timeout - age_s ))
      local lead="${HERMES_TAILSCALE_UP_UPGRADE_LEAD_SECS:-900}"
      local refresh="${HERMES_TAILSCALE_AUTHURL_REFRESH_SECS:-2700}"
      local _trigger=0
      if (( _remain <= lead )); then _trigger=1; fi
      # Finite→finite upgrades may also use the ~45m refresh age (legacy #130).
      if (( desired_up_timeout > 0 )) && (( age_s >= refresh )); then _trigger=1; fi
      # Tip #132: finite→forever soft upgrade remints AuthURL (proven tip#130
      # 80d5b860→184ff33a). While status still advertises a live AuthURL, hold it —
      # do not kill+re-up early. Start forever only after AuthURL is gone / FORCE.
      if (( _trigger == 1 )) && (( desired_up_timeout == 0 )) \
        && [[ "${HERMES_AUTHURL_FORCE_REFRESH:-0}" != "1" ]]; then
        _live_for_upgrade=""
        _live_for_upgrade="$(sudo tailscale --socket="${SOCK:-/var/run/tailscale/tailscaled.sock}" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print((d.get("AuthURL") or "").strip())
except Exception:
  print("")' 2>/dev/null || true)"
        if [[ -n "${_live_for_upgrade}" ]]; then
          # Tip #135: tip#132 skip avoids forever remint, but finite up still expires
          # and a post-expiry forever start remints anyway. Near expiry, soft-roll to
          # another *finite* long timeout (default LOGIN_WAIT 14400). Soft remint
          # often keeps the same AuthURL (tip#123); forever upgrade remints (tip#130).
          local roll="${HERMES_TAILSCALE_AUTHURL_FINITE_ROLL_SECS:-${HERMES_TAILSCALE_LOGIN_WAIT_SECS:-14400}}"
          local roll_lead="${HERMES_TAILSCALE_AUTHURL_FINITE_ROLL_LEAD_SECS:-1800}"
          if [[ "${HERMES_TAILSCALE_AUTHURL_FINITE_ROLL:-1}" == "1" ]] \
            && [[ "${roll}" =~ ^[0-9]+$ ]] && (( roll > 0 )) \
            && (( _remain <= roll_lead )); then
            echo "WARN tip#135 finite AuthURL hold-roll ${_up_timeout}s → ${roll}s (live AuthURL remain_s=${_remain} ≤ roll_lead=${roll_lead}; avoid forever/expiry remint)"
            echo "roll=$(date -u +%FT%TZ) from=${_up_timeout} to=${roll} age_s=${age_s} remain_s=${_remain}" \
              >>"${SCRIPT_DIR}/LAST_UP_TIMEOUT_UPGRADE.txt" 2>/dev/null || true
            desired_up_timeout="$roll"
            # Tip #136: persist so any sibling wait-login reads roll secs instead of forever=0
            printf '%s\n' "$roll" >"${SCRIPT_DIR}/DESIRED_UP_TIMEOUT.txt" 2>/dev/null || true
            echo "OK tip#136 persisted DESIRED_UP_TIMEOUT=${roll}"
            _do_restart=1
            _upgrade_short=1
            _trigger=0
          else
            local every="${HERMES_WAIT_LOGIN_STATUS_EVERY_SECS:-60}" stamp="$SCRIPT_DIR/LAST_UP_OK_ECHO.at" now
            now="$(date +%s)"
            if [[ ! -f "$stamp" ]] || (( now - $(cat "$stamp" 2>/dev/null || echo 0) >= every )); then
              echo "OK tip#132 skip finite→forever upgrade — live AuthURL still advertised (timeout=${_up_timeout}s remain_s=${_remain}; tip#135 roll when remain≤${roll_lead:-1800})"
              echo "$now" >"$stamp"
            fi
            _trigger=0
          fi
        fi
      fi
      if (( _trigger == 1 )); then
        _do_restart=1
        _upgrade_short=1
        echo "WARN tip#130/#131 controlled up-timeout upgrade ${_up_timeout}s → ${desired_up_timeout}s (age_s=${age_s} remain_s=${_remain} lead_s=${lead}; 0=forever)"
        echo "upgrade=$(date -u +%FT%TZ) from=${_up_timeout} to=${desired_up_timeout} age_s=${age_s} remain_s=${_remain}" \
          >>"${SCRIPT_DIR}/LAST_UP_TIMEOUT_UPGRADE.txt" 2>/dev/null || true
        # Soft remint may keep or change AuthURL — flag MCP surface so agents re-check.
        echo "tip132_upgrade=$(date -u +%FT%TZ) from=${_up_timeout} to=${desired_up_timeout}" \
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
      # Tip #136: take exclusive TS_UP_LOCK BEFORE kill so a sibling wait-login cannot
      # start forever=0 mid-roll (proven remint 184ff33a→e064be30 @ tip#135).
      # Do NOT force hard merely because GH_TOKEN_INVALID / AUTHURL_MCP_SURFACE_NEEDED —
      # those mean tip/beacon must go via MCP, not that the AuthURL is dead.
      # Opt in to hard wipe: HERMES_AUTHURL_HARD_ON_REFRESH=1 (or restart-authurl-hard.sh).
      # Force soft remint: HERMES_AUTHURL_FORCE_REFRESH=1.
      exec 9>"$TS_UP_LOCK"
      if ! flock -n 9; then
        echo "OK tip#136 skip restart — another process holds tailscale-up lock (single-flight)"
        _refresh_authurl_file
        return 0
      fi
      if [[ "${HERMES_AUTHURL_HARD_ON_REFRESH:-0}" == "1" ]]; then _hard=1; fi
      if [[ "$_upgrade_short" == "1" ]]; then
        echo "OK AuthURL refresh mode=SOFT upgrade (tip#130/#131/#136 short-timeout → ${desired_up_timeout}s; 0=forever; lock held)"
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
        if [[ -n "${_up_timeout}" ]] && { (( desired_up_timeout == 0 && _up_timeout > 0 )) || (( desired_up_timeout > 0 && _up_timeout < desired_up_timeout )); }; then
          echo "OK tip#130/#131/#132 short up still young (timeout=${_up_timeout}s desired=${desired_up_timeout}s age_s=${age_s:-?} remain_s=$((_up_timeout - age_s)); forever-upgrade only after AuthURL gone; 0=forever)"
        fi
        echo "OK tailscale up wait already running (pidfile=$(cat "$TS_UP_PIDFILE" 2>/dev/null || echo none) age_s=${age_s:-?})"
        echo "$now" >"$stamp"
      fi
      _refresh_authurl_file
      return 0
    fi
  fi
  # Tip #136: if restart path already holds fd 9, skip re-open; else acquire exclusive.
  if ! { true >&9; } 2>/dev/null; then
    exec 9>"$TS_UP_LOCK"
    if ! flock -n 9; then
      echo "OK another process holds tailscale-up lock"
      _refresh_authurl_file
      return 0
    fi
  fi
  if _tailscale_up_wait_running; then
    _refresh_authurl_file
    return 0
  fi
  # Tip #136: if live AuthURL still advertised and a recent up died, prefer persisted
  # finite timeout over forever=0 (forever cold-start reminted e064be30→6ad13a30).
  if (( desired_up_timeout == 0 )) && [[ "${HERMES_AUTHURL_FORCE_FOREVER_START:-0}" != "1" ]]; then
    _live_for_start=""
    _live_for_start="$(sudo tailscale --socket="${SOCK:-/var/run/tailscale/tailscaled.sock}" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print((d.get("AuthURL") or "").strip())
except Exception:
  print("")' 2>/dev/null || true)"
    if [[ -n "${_live_for_start}" ]]; then
      local _safe="${HERMES_TAILSCALE_AUTHURL_FINITE_ROLL_SECS:-${HERMES_TAILSCALE_LOGIN_WAIT_SECS:-14400}}"
      if [[ "${_safe}" =~ ^[0-9]+$ ]] && (( _safe > 0 )); then
        echo "WARN tip#136 cold-start with live AuthURL — using finite ${_safe}s instead of forever=0 (avoid remint; set HERMES_AUTHURL_FORCE_FOREVER_START=1 to override)"
        desired_up_timeout="$_safe"
        printf '%s\n' "$_safe" >"${SCRIPT_DIR}/DESIRED_UP_TIMEOUT.txt" 2>/dev/null || true
      fi
    fi
  fi
  # Tip #131/#136: interactive up --timeout; persist whatever we start with.
  printf '%s\n' "${desired_up_timeout}" >"${SCRIPT_DIR}/DESIRED_UP_TIMEOUT.txt" 2>/dev/null || true
  echo "== starting single tailscale up wait (up_timeout=${desired_up_timeout}s; 0=forever; script_wait=${login_wait_secs}s; tip136) =="
  nohup sudo tailscale --socket="$SOCK" up --timeout="${desired_up_timeout}s" \
    --hostname="${HERMES_TS_HOSTNAME:-cursor-cloud-hermes}" --accept-routes=true \
    >/tmp/tailscale-up-wait.log 2>&1 &
  echo $! >"$TS_UP_PIDFILE"
  echo "OK started tailscale up wait pid=$(cat "$TS_UP_PIDFILE") desired=${desired_up_timeout}"
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
        # Throttle verbose `ts status` (Logged out / AuthURL) — was every 5–8s → multi-MB logs.
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
  # Tip #133: single-flight downstream (flock + success-only marker).
  once="$SCRIPT_DIR/hermes-cloud-run-downstream-once.sh"
  if [[ ! -x "$once" ]]; then
    echo "ERROR: missing $once" >&2
    exit 1
  fi
  export HERMES_CLOUD_APPLY_DIR="${HERMES_CLOUD_APPLY_DIR:-$SCRIPT_DIR}"
  bash "$once"
  echo "OK cloud-tailscale-join-and-apply finished (downstream-only)"
  exit 0
fi

export HERMES_JUMP_SSH="$JUMP_SSH"
bash "$SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"

echo "OK cloud-tailscale-join-and-apply finished (expect OK INTERRUPT_LABEL hermes-now)"
exit 0
