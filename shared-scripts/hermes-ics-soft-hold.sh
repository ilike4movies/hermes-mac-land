#!/bin/bash
# hermes-ics-soft-hold.sh — tip #168/#169
# Standalone CDN TIP_PIN hot-pick + ICS tip-stale/TTL soft-hold.
# Safe to curl|bash from cloud agents/timers without reminting AuthURL or
# respawning wait-login. Preserves UID/DTEND/URL on tip-stale rewrite.
set -euo pipefail
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
if [[ -n "${HERMES_ICS_SOFT_HOLD_DIR:-}" ]]; then
  SCRIPT_DIR="$HERMES_ICS_SOFT_HOLD_DIR"
else
  SCRIPT_DIR="${SCRIPT_DIR:-}"
  if [[ -z "${SCRIPT_DIR}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  fi
  # Prefer apply/cloud dir when present (live wait-login mirror).
  for d in /tmp/hermes-cloud-apply /tmp/hermes-mac-land "$SCRIPT_DIR"; do
    if [[ -f "$d/HERMES-APPROVE-TAILSCALE.ics" || -f "$d/TIP_PIN" ]]; then
      SCRIPT_DIR="$d"
      break
    fi
  done
fi
ICS="${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics"
PINFILE="${SCRIPT_DIR}/TIP_PIN"
HOLD_HOURS="${HERMES_AUTHURL_ICS_HOLD_HOURS:-6}"
REMAIN_SECS="${HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS:-1800}"

_cdn_tip() {
  curl -fsSL --max-time "${HERMES_TIP_PIN_CDN_TIMEOUT_SECS:-3}" \
    "https://raw.githubusercontent.com/${REPO}/main/TIP_PIN" 2>/dev/null \
    | tr -dc '0-9' | head -c 8 || true
}

_local_tip() {
  if [[ -f "$PINFILE" ]]; then
    tr -dc '0-9' <"$PINFILE" | head -c 8 || true
  fi
}

_tip_max() {
  local a="${1:-}" b="${2:-}"
  if [[ -z "$a" ]]; then echo "$b"; return; fi
  if [[ -z "$b" ]]; then echo "$a"; return; fi
  if (( 10#$a > 10#$b )); then echo "$a"; else echo "$b"; fi
}

url="$(SCRIPT_DIR="$SCRIPT_DIR" python3 - <<'PY'
import json, subprocess, re, os
url=""
try:
    st=json.loads(subprocess.check_output(["sudo","tailscale","status","--json"], text=True, timeout=10))
    url=(st.get("AuthURL") or "").strip()
except Exception:
    pass
base=os.environ.get("SCRIPT_DIR") or ""
if not url:
    for p in ("CURRENT_AUTHURL.md","CURRENT_AUTHURL.txt","PENDING_AUTHURL_TIP.txt"):
        path=os.path.join(base, p)
        try:
            t=open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        m=re.search(r"https://login\.tailscale\.com/a/[a-z0-9]+", t)
        if m:
            url=m.group(0); break
print(url)
PY
)"

local_tip="$(_local_tip)"
cdn_tip="$(_cdn_tip)"
tip="${HERMES_AUTHURL_ICS_EXPECTED_TIP:-}"
if [[ -z "$tip" ]]; then
  tip="$(_tip_max "$local_tip" "$cdn_tip")"
fi
tip="${tip:-169}"
if [[ -n "$cdn_tip" && "$cdn_tip" == "$tip" && "${HERMES_TIP_PIN_CDN_SYNC:-1}" == "1" ]]; then
  printf '%s\n' "$cdn_tip" >"$PINFILE" 2>/dev/null || true
fi
echo "tip168 soft-hold dir=$SCRIPT_DIR tip=$tip local=${local_tip:--} cdn=${cdn_tip:--} url=${url:-none}"

if [[ -z "$url" ]]; then
  echo "WARN tip168: no AuthURL; tip pin synced only"
  exit 0
fi

need_ttl=0
need_tip=0
if [[ ! -f "$ICS" ]]; then
  need_ttl=1
else
  if ! ICS_PATH="$ICS" REMAIN="$REMAIN_SECS" python3 - <<'PY'
import os, re
from datetime import datetime, timezone
path=os.environ["ICS_PATH"]; remain=int(os.environ["REMAIN"])
text=open(path, encoding="utf-8", errors="replace").read()
m=re.search(r"^DTEND:([0-9]{8}T[0-9]{6}Z)$", text, re.M)
if not m: raise SystemExit(1)
end=datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
raise SystemExit(0 if (end-datetime.now(timezone.utc)).total_seconds() > remain else 1)
PY
  then need_ttl=1; fi
  if ! ICS_PATH="$ICS" EXPECT="$tip" python3 - <<'PY'
import os, re
path=os.environ["ICS_PATH"]; expect=int(os.environ["EXPECT"])
text=open(path, encoding="utf-8", errors="replace").read()
m=re.search(r"^SUMMARY:.*\(tip #(\d+)\)", text, re.M)
if not m: raise SystemExit(1)
raise SystemExit(0 if int(m.group(1)) >= expect else 1)
PY
  then need_tip=1; fi
fi

if [[ "$need_ttl" == "1" ]]; then
  AUTHURL_ICS_URL="$url" HERMES_AUTHURL_ICS_EXPECTED_TIP="$tip" HERMES_AUTHURL_ICS_HOLD_HOURS="$HOLD_HOURS" \
  python3 - <<'ICS' >"$ICS"
import os
from datetime import datetime, timedelta, timezone
url=os.environ["AUTHURL_ICS_URL"]
suffix=url.rstrip("/").rsplit("/",1)[-1]
tip=os.environ.get("HERMES_AUTHURL_ICS_EXPECTED_TIP") or "169"
hours=int(os.environ.get("HERMES_AUTHURL_ICS_HOLD_HOURS") or "6")
now=datetime.now(timezone.utc)
end=now+timedelta(hours=hours)
stamp=now.strftime("%Y%m%dT%H%M%SZ")
dend=end.strftime("%Y%m%dT%H%M%SZ")
print(f"""BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Hermes Mac Land//AuthURL Wake//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
BEGIN:VEVENT
UID:hermes-authurl-{suffix}@hermes-mac-land
DTSTAMP:{stamp}
DTSTART:{stamp}
DTEND:{dend}
SUMMARY:ACTION: Approve Hermes Tailscale AuthURL {suffix} (tip #{tip})
DESCRIPTION:Approve NOW: {url}\\nThen Mac ONE-SHOT tip #{tip} (CDN TIP_PIN hot-pick #168; #166 tip-stale; #162 STALL/ONLY; #161 ENABLE; FALLBACK b2b5fc4 tip159). Runtime Secrets HERMES_HOST_SSH_PRIVATE_KEY + LINEAR_API_KEY also OK on LEGACY .11.
URL:{url}
STATUS:CONFIRMED
SEQUENCE:1
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Approve Tailscale AuthURL {suffix} NOW — Mac ONE-SHOT tip #{tip}
TRIGGER:-PT0M
END:VALARM
END:VEVENT
END:VCALENDAR""")
ICS
  echo "OK tip #$tip ICS TTL soft-hold rewritten (hold=${HOLD_HOURS}h)"
elif [[ "$need_tip" == "1" ]]; then
  AUTHURL_ICS_URL="$url" ICS_PATH="$ICS" HERMES_AUTHURL_ICS_EXPECTED_TIP="$tip" python3 - <<'PY'
import os, re
path=os.environ["ICS_PATH"]; url=os.environ["AUTHURL_ICS_URL"]
suffix=url.rstrip("/").rsplit("/",1)[-1]
tip=os.environ.get("HERMES_AUTHURL_ICS_EXPECTED_TIP") or "169"
text=open(path, encoding="utf-8", errors="replace").read()
summary=f"SUMMARY:ACTION: Approve Hermes Tailscale AuthURL {suffix} (tip #{tip})"
desc=(
  f"DESCRIPTION:Approve NOW: {url}\\n"
  f"Then Mac ONE-SHOT tip #{tip} (CDN TIP_PIN hot-pick #168; #166 tip-stale; #162 STALL/ONLY; #161 ENABLE; FALLBACK b2b5fc4 tip159). "
  "Runtime Secrets HERMES_HOST_SSH_PRIVATE_KEY + LINEAR_API_KEY also OK on LEGACY .11."
)
valarm=f"DESCRIPTION:Approve Tailscale AuthURL {suffix} NOW — Mac ONE-SHOT tip #{tip}"
out=[]; in_valarm=False
for line in text.splitlines():
    if line.startswith("BEGIN:VALARM"):
        in_valarm=True; out.append(line); continue
    if line.startswith("END:VALARM"):
        in_valarm=False; out.append(line); continue
    if line.startswith("SUMMARY:"):
        out.append(summary)
    elif line.startswith("DESCRIPTION:"):
        out.append(valarm if in_valarm else desc)
    else:
        out.append(line)
open(path,"w",encoding="utf-8").write("\n".join(out)+("\n" if text.endswith("\n") else ""))
print(f"OK tip #{tip} ICS tip-pin soft-hold (DTEND preserved)")
PY
else
  echo "OK tip #$tip ICS already current (no rewrite)"
fi
