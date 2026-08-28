#!/usr/bin/env bash
# Soft AuthURL restart for cloud waiters (kill up + respawn wait-login).
# Often reissues the SAME login URL while NeedsLogin — prefer restart-authurl-hard.sh
# when you need a truly fresh AuthURL (#115).
#
# Young-up guard (#117): refuses to kill interactive `tailscale up` younger than
# HERMES_TAILSCALE_AUTHURL_REFRESH_SECS (default 2700) unless
# HERMES_FORCE_AUTHURL_RESTART=1. Incomplete soft-kills of young root-owned ups
# mint a NEW AuthURL mid-approve (see tip #116 sudo-kill note).
#
# Usage:
#   bash restart-authurl.sh
#   HERMES_FORCE_AUTHURL_RESTART=1 bash restart-authurl.sh
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
cd "$DIR"
OLD="$(head -1 CURRENT_AUTHURL.txt 2>/dev/null || true)"
echo "OLD=${OLD:-none}"

min_age="${HERMES_TAILSCALE_AUTHURL_REFRESH_SECS:-2700}"
force="${HERMES_FORCE_AUTHURL_RESTART:-0}"
young=0
age_s=0
if [[ -f tailscale-up-wait.pid ]]; then
  pid="$(tr -d ' \r\n' < tailscale-up-wait.pid || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    age_s="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)"
  fi
fi
if [[ -z "${age_s:-}" || "$age_s" == "0" ]]; then
  pid="$(pgrep -f 'tailscale.* up --timeout' 2>/dev/null | head -1 || true)"
  if [[ -n "${pid:-}" ]]; then
    age_s="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)"
  fi
fi
if [[ "${age_s:-0}" =~ ^[0-9]+$ ]] && (( age_s > 0 && age_s < min_age )); then
  young=1
fi
if [[ "$young" == "1" && "$force" != "1" ]]; then
  echo "REFUSE soft AuthURL restart — up age_s=${age_s} < refresh=${min_age}s (set HERMES_FORCE_AUTHURL_RESTART=1 to override)"
  echo "Prefer: attach wait-login only, or wait for ~45m hard refresh (#115), or Mac ONE-SHOT."
  exit 0
fi
if [[ "$force" == "1" && "$young" == "1" ]]; then
  echo "WARN FORCE soft restart of young up age_s=${age_s}"
fi

# Stop wait-login join (supervisor will respawn) and interactive up
pkill -f 'hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login' || true
# Prefer sudo kill for root-owned up (#116)
python3 - <<'PYKILL' 2>/dev/null || true
import subprocess, time
out = subprocess.check_output(["ps", "-eo", "pid,args"], text=True)
for line in out.splitlines():
    args = line.split(None, 1)[1] if " " in line else ""
    is_up = ("up --timeout" in args) and (
        args.startswith("sudo tailscale")
        or args.startswith("tailscale ")
        or args.startswith("/usr/bin/tailscale")
    )
    if not is_up:
        continue
    pid = line.split()[0]
    print(f"TERM {pid} {args[:100]}")
    subprocess.run(["sudo", "kill", "-TERM", pid], check=False)
    subprocess.run(["kill", "-TERM", pid], check=False)
time.sleep(1)
PYKILL
rm -f tailscale-up-wait.pid
sleep 3
# Fresh wait-login
nohup env HERMES_AUTO_SURGICAL_LAND="${HERMES_AUTO_SURGICAL_LAND:-0}" \
  bash ./hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login >>./wait-login.log 2>&1 &
echo "waitlogin=$!"
for i in $(seq 1 12); do
  sleep 5
  url="$(sudo tailscale status 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[a-z0-9]+' | head -1 || true)"
  echo "t=$((i*5)) url=${url:-none}"
  if [[ -n "$url" ]]; then
    {
      printf '%s\n' "$url"
      printf 'ACTIVE — approve now (%s).\n' "$(date -u +%FT%TZ)"
      echo 'Soft restart; prefer hard rotate if URL unchanged. Cloud waiters armed.'
    } > CURRENT_AUTHURL.txt
    if [[ "$url" != "$OLD" ]]; then
      echo "FRESH_URL=$url"
    else
      echo "SAME_OR_REISSUED_URL=$url"
    fi
    break
  fi
done
cat CURRENT_AUTHURL.txt
pgrep -af 'join-and-apply.sh --wait|up --timeout' | head -5 || true
sudo tailscale status 2>&1 | head -5 || true
