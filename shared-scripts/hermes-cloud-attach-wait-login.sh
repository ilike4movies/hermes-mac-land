#!/usr/bin/env bash
# hermes-cloud-attach-wait-login.sh — Tip #137 safe wait-login attach (no AuthURL remint)
#
# Prefer this over restart-authurl.sh / manual `tailscale up` when NeedsLogin still
# advertises a live AuthURL. Proven remint chain (tip#135/#136 era):
#   184ff33a → e064be30 → 6ad13a30 → 1d0d8050 when agents cold-started forever up.
#
# Behavior:
#   1) Kill only join --wait-login by exact PID (never pkill -f; avoids self-match).
#   2) NEVER kill interactive `tailscale up` (refuse unless HERMES_FORCE_KILL_UP=1).
#   3) If no up is running AND AuthURL is still advertised: REFUSE to start up
#      (set HERMES_FORCE_COLD_UP=1 to override — expect remint + tip/MCP surface).
#   4) Spawn one wait-login with soft AuthURL keep-alive + tip#136 env.
#
# Usage:
#   bash shared-scripts/hermes-cloud-attach-wait-login.sh
#   HERMES_CLOUD_APPLY_DIR=/tmp/hermes-cloud-apply bash hermes-cloud-attach-wait-login.sh
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
cd "$DIR"

authurl_now() {
  sudo tailscale --socket="$SOCK" status --json 2>/dev/null | python3 -c 'import json,sys
try:
  print((json.load(sys.stdin).get("AuthURL") or "").strip())
except Exception:
  print("")' 2>/dev/null || true
}

BEFORE="$(authurl_now)"
export _TIP137_AUTHURL="$BEFORE"
echo "tip137 attach-wait-login BEFORE_AUTHURL=${BEFORE:-none}"

python3 - <<'PY'
import os, subprocess, time
from pathlib import Path

DIR = Path(os.environ.get("HERMES_CLOUD_APPLY_DIR", "/tmp/hermes-cloud-apply"))
FORCE_KILL_UP = os.environ.get("HERMES_FORCE_KILL_UP", "0") == "1"
FORCE_COLD = os.environ.get("HERMES_FORCE_COLD_UP", "0") == "1"
me = str(os.getpid())

def lines():
    return subprocess.check_output(["ps", "-eo", "pid,args"], text=True).splitlines()

waits, ups = [], []
for line in lines():
    if "extglob" in line:
        continue
    parts = line.split(None, 1)
    if len(parts) < 2:
        continue
    pid, args = parts[0], parts[1]
    if pid == me:
        continue
    if "hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login" in args:
        waits.append(pid)
    if "up --timeout" in args and "tailscale" in args:
        ups.append(pid)

print(f"tip137 waits={waits} ups={ups}")
for pid in waits:
    print(f"tip137 TERM wait-login pid={pid}")
    subprocess.run(["kill", "-TERM", pid], check=False)
time.sleep(2)

# Re-scan ups after wait kill
ups = []
for line in lines():
    if "extglob" in line:
        continue
    parts = line.split(None, 1)
    if len(parts) < 2:
        continue
    pid, args = parts[0], parts[1]
    if "up --timeout" in args and "tailscale" in args:
        ups.append(pid)

auth = os.environ.get("_TIP137_AUTHURL", "")
if not ups:
    if auth and not FORCE_COLD:
        print("REFUSE tip137: live AuthURL + no up — cold-start remints (set HERMES_FORCE_COLD_UP=1 to override)")
        raise SystemExit(2)
    if FORCE_KILL_UP:
        print("WARN tip137 HERMES_FORCE_KILL_UP ignored — no up running")
    print("WARN tip137 no up running — wait-login may cold-start (tip#136 prefers finite if AuthURL live)")
elif FORCE_KILL_UP:
    print("WARN tip137 HERMES_FORCE_KILL_UP=1 — killing ups (will remint)")
    for pid in ups:
        subprocess.run(["sudo", "kill", "-TERM", pid], check=False)
        subprocess.run(["kill", "-TERM", pid], check=False)
    time.sleep(2)
else:
    print(f"OK tip137 keeping up pids={ups}")

env = os.environ.copy()
env.setdefault("HERMES_AUTHURL_HARD_ON_REFRESH", "0")
env.setdefault("HERMES_TAILSCALE_UP_TIMEOUT_SECS", "0")
# Tip #136 race fix: if DESIRED_UP_TIMEOUT persist has finite roll, keep it.
persist = DIR / "DESIRED_UP_TIMEOUT.txt"
if persist.is_file():
    raw = persist.read_text().strip()
    if raw.isdigit() and int(raw) > 0:
        env["HERMES_TAILSCALE_UP_TIMEOUT_SECS"] = raw
        print(f"OK tip137 adopt DESIRED_UP_TIMEOUT={raw}")
env.setdefault("HERMES_AUTO_SURGICAL_LAND", "0")
env["HERMES_CLOUD_APPLY_DIR"] = str(DIR)

join = DIR / "hermes-moltbot-cloud-tailscale-join-and-apply.sh"
if not join.is_file():
    raise SystemExit(f"missing {join}")
log = open(DIR / "wait-login.log", "a")
p = subprocess.Popen(
    ["bash", str(join), "--wait-login"],
    cwd=str(DIR),
    env=env,
    stdout=log,
    stderr=subprocess.STDOUT,
    start_new_session=True,
)
(DIR / "waiter.pid").write_text(str(p.pid))
print(f"OK tip137 spawned wait-login pid={p.pid}")
time.sleep(5)
PY

AFTER="$(authurl_now)"
echo "tip137 attach-wait-login AFTER_AUTHURL=${AFTER:-none}"
if [[ -n "${BEFORE}" && -n "${AFTER}" && "${BEFORE}" != "${AFTER}" ]]; then
  echo "WARN tip137 AuthURL changed — surface via tip CURRENT / Gmail / RAL-823 / issue #1"
  echo "changed=$(date -u +%FT%TZ) from=${BEFORE} to=${AFTER}" >>"$DIR/AUTHURL_MCP_SURFACE_NEEDED.txt" 2>/dev/null || true
  exit 3
fi
echo "OK tip137 AuthURL unchanged (or none)"
pgrep -af 'hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login' | grep -v extglob | head -3 || true
pgrep -af 'tailscale.* up --timeout' | grep -v extglob | head -3 || true
exit 0
