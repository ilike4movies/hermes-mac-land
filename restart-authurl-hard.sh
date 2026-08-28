#!/usr/bin/env bash
# Hard Tailscale AuthURL rotate for cloud waiters.
# Soft restart-authurl.sh often reissues the SAME login URL while NeedsLogin.
# This wipes /var/lib/tailscale/tailscaled.state so Tailscale mints a fresh AuthURL.
#
# Usage (from /tmp/hermes-cloud-apply or any dir with the join script):
#   bash restart-authurl-hard.sh
#
# Does NOT kill secrets-bridge / on-join watcher / supervisor.
# Safe to run while still NeedsLogin. After success, surface NEW URL via tip MCP
# if gh tip write is unavailable (see PENDING_AUTHURL_TIP.txt).
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
cd "$DIR"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
STATE="${HERMES_TAILSCALED_STATE:-/var/lib/tailscale/tailscaled.state}"
OLD="$(head -1 CURRENT_AUTHURL.txt 2>/dev/null || true)"
echo "OLD=${OLD:-none}"

# Stop join wait-login + interactive up only (python kill avoids self-match).
python3 - <<'PY'
import os, signal, subprocess, time
out = subprocess.check_output(["ps", "-eo", "pid,args"], text=True)
for line in out.splitlines():
    args = line.split(None, 1)[1] if " " in line else ""
    kill = False
    if "hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login" in args:
        kill = True
    if args.startswith("sudo tailscale") or args.startswith("tailscale"):
        if "up --timeout" in args:
            kill = True
    if not kill:
        continue
    pid = int(line.split()[0])
    print(f"TERM {pid} {args[:100]}")
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
time.sleep(2)
PY
rm -f tailscale-up-wait.pid

sudo tailscale --socket="$SOCK" logout 2>/dev/null || true
sudo rm -fv "$STATE" "${STATE}.tmp" 2>/dev/null || true

# Ensure daemon is up with empty state
if ! sudo tailscale --socket="$SOCK" status >/dev/null 2>&1; then
  if ! pgrep -x tailscaled >/dev/null 2>&1; then
    sudo tailscaled --state="$STATE" --socket="$SOCK" --port=41641 \
      >>"$DIR/tailscaled-hard-rotate.log" 2>&1 &
    sleep 2
  fi
fi

# Fresh wait-login (starts tailscale up)
nohup env HERMES_AUTO_SURGICAL_LAND=0 \
  bash ./hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login \
  >>./wait-login.log 2>&1 &
echo "waitlogin=$!"
echo $! >waiter.pid

url=""
for i in $(seq 1 24); do
  sleep 5
  url="$(sudo tailscale --socket="$SOCK" status 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[a-z0-9]+' | head -1 || true)"
  echo "t=$((i * 5))s url=${url:-none}"
  if [[ -n "$url" ]]; then
    break
  fi
done

if [[ -z "$url" ]]; then
  echo "FAIL: no AuthURL after hard rotate" >&2
  sudo tailscale --socket="$SOCK" status 2>&1 | head -10 >&2 || true
  exit 1
fi

{
  printf '%s\n' "$url"
  printf 'ACTIVE — approve now (%s).\n' "$(date -u +%FT%TZ)"
  echo 'Hard state wipe — fresh AuthURL. Soft restart often reissues the same URL.'
} >CURRENT_AUTHURL.txt
{
  printf '%s\n' "$url"
  printf 'refreshed=%s\n' "$(date -u +%FT%TZ)"
} >PENDING_AUTHURL_TIP.txt

if [[ "$url" != "$OLD" ]]; then
  echo "FRESH_URL=$url"
else
  echo "SAME_OR_REISSUED_URL=$url"
fi
cat CURRENT_AUTHURL.txt
sudo tailscale --socket="$SOCK" status 2>&1 | head -5
