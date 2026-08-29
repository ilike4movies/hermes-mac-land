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
      echo 'Cloud waiters armed; TS_AUTHKEY preferred. Proactive refresh before prior TTL.'
    } >"$authfile"
    echo "APPROVE_THIS_URL=$url"
  fi
  # Tip #134: soft-hold ICS rewrite when calendar window is expired/near-expiry
  # while the same AuthURL is still advertised (avoids mid-approve calendar miss).
  local ics_need_refresh=0
  local ics_local="${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics"
  if [[ ! -f "$ics_local" ]]; then
    ics_need_refresh=1
  elif command -v python3 >/dev/null 2>&1; then
    if ! ICS_PATH="$ics_local" HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS="${HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS:-1800}" python3 - <<'PY'
import os, re
from datetime import datetime, timezone
path = os.environ["ICS_PATH"]
remain = int(os.environ.get("HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS") or "1800")
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    raise SystemExit(1)
m = re.search(r"^DTEND:([0-9]{8}T[0-9]{6}Z)$", text, re.M)
if not m:
    raise SystemExit(1)
end = datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
raise SystemExit(0 if (end - now).total_seconds() > remain else 1)
PY
    then
      ics_need_refresh=1
    fi
  fi
  # Keep PENDING + local ICS aligned even if CURRENT was written out-of-band
  # (hard wipe / agent MCP) so cloud agents do not read a stale AuthURL marker.
  # Tip #134: also rewrite when ICS hold window is nearly expired (soft AuthURL hold).
  if [[ "$auth_changed" == "1" || "$pending_stale" == "1" || "$ics_need_refresh" == "1" ]]; then
    {
      printf '%s\n' "$url"
      printf 'refreshed=%s\n' "$(date -u +%FT%TZ)"
    } >"$pending"
    if command -v python3 >/dev/null 2>&1; then
      AUTHURL_ICS_URL="$url" HERMES_AUTHURL_ICS_HOLD_HOURS="${HERMES_AUTHURL_ICS_HOLD_HOURS:-6}" python3 - <<'ICS' >"${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics" 2>/dev/null || true
import os
from datetime import datetime, timedelta, timezone
url = os.environ["AUTHURL_ICS_URL"]
suffix = url.rstrip("/").rsplit("/", 1)[-1][:12]
now = datetime.now(timezone.utc)
dt = now.strftime("%Y%m%dT%H%M%SZ")
hold_h = max(1, int(os.environ.get("HERMES_AUTHURL_ICS_HOLD_HOURS") or "6"))
end = (now + timedelta(hours=hold_h)).strftime("%Y%m%dT%H%M%SZ")
uid = f"hermes-authurl-{suffix}-{int(now.timestamp())}@hermes-mac-land"
print(f"""BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Hermes Mac Land//AuthURL Wake//EN
CALSCALE:GREGORIAN
METHOD:REQUEST
BEGIN:VEVENT
UID:{uid}
DTSTAMP:{dt}
DTSTART:{dt}
DTEND:{end}
SUMMARY:ACTION: Approve Hermes Tailscale AuthURL {suffix}
DESCRIPTION:Approve NOW: {url}\\nThen add Runtime Secrets HERMES_HOST_SSH_PRIVATE_KEY + LINEAR_API_KEY.\\nOr Mac ONE-SHOT from hermes-mac-land tip.
LOCATION:{url}
URL:{url}
STATUS:CONFIRMED
SEQUENCE:0
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Approve Tailscale AuthURL {suffix} NOW
TRIGGER:-PT0S
END:VALARM
END:VEVENT
END:VCALENDAR""")
ICS
    fi
  fi
  # Tip #134: when AuthURL is unchanged but ICS hold expired, still refresh tip ICS
  # (does not remint AuthURL; throttled by local rewrite above).
  if [[ "$ics_need_refresh" == "1" && "$auth_changed" != "1" && "${HERMES_AUTHURL_TIP_ICS:-1}" == "1" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      local tip_tok="${GITHUB_TOKEN:-${GH_TOKEN:-${HERMES_GH_WORKFLOW_PAT:-}}}"
      local tip_owner tip_name gh_repo="${HERMES_STATUS_GITHUB_REPO:-ilike4movies/hermes-mac-land}"
      tip_owner="${gh_repo%%/*}"
      tip_name="${gh_repo#*/}"
      local ics_path="HERMES-APPROVE-TAILSCALE.ics" ics_body ics_sha ics_b64 ics_api ics_payload
      ics_body="$(AUTHURL_ICS_URL="$url" HERMES_AUTHURL_ICS_HOLD_HOURS="${HERMES_AUTHURL_ICS_HOLD_HOURS:-6}" python3 - <<'ICS'
import os
from datetime import datetime, timedelta, timezone
url = os.environ["AUTHURL_ICS_URL"]
suffix = url.rstrip("/").rsplit("/", 1)[-1][:12]
now = datetime.now(timezone.utc)
dt = now.strftime("%Y%m%dT%H%M%SZ")
hold_h = max(1, int(os.environ.get("HERMES_AUTHURL_ICS_HOLD_HOURS") or "6"))
end = (now + timedelta(hours=hold_h)).strftime("%Y%m%dT%H%M%SZ")
uid = f"hermes-authurl-{suffix}-{int(now.timestamp())}@hermes-mac-land"
print(f"""BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Hermes Mac Land//AuthURL Wake//EN
CALSCALE:GREGORIAN
METHOD:REQUEST
BEGIN:VEVENT
UID:{uid}
DTSTAMP:{dt}
DTSTART:{dt}
DTEND:{end}
SUMMARY:ACTION: Approve Hermes Tailscale AuthURL {suffix}
DESCRIPTION:Approve NOW: {url}\\nThen add Runtime Secrets HERMES_HOST_SSH_PRIVATE_KEY + LINEAR_API_KEY.\\nOr Mac ONE-SHOT from hermes-mac-land tip.
LOCATION:{url}
URL:{url}
STATUS:CONFIRMED
SEQUENCE:0
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Approve Tailscale AuthURL {suffix} NOW
TRIGGER:-PT0S
END:VALARM
END:VEVENT
END:VCALENDAR""")
ICS
)"
      ics_sha=""
      if command -v gh >/dev/null 2>&1; then
        ics_sha="$(gh api "repos/${gh_repo}/contents/${ics_path}" --jq .sha 2>/dev/null || true)"
      elif [[ -n "$tip_tok" ]] && command -v curl >/dev/null 2>&1; then
        ics_sha="$(curl -fsS -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"           "https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${ics_path}" 2>/dev/null           | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sha",""))' 2>/dev/null || true)"
      fi
      ics_b64="$(printf '%s' "$ics_body" | base64 | tr -d '\n')"
      if command -v gh >/dev/null 2>&1; then
        if [[ -n "$ics_sha" ]]; then
          gh api --method PUT "repos/${gh_repo}/contents/${ics_path}" -f message="ops: soft-hold refresh HERMES-APPROVE-TAILSCALE.ics (#134)" -f content="$ics_b64" -f branch=main -f sha="$ics_sha" >/dev/null 2>&1 && echo "OK tip HERMES-APPROVE-TAILSCALE.ics soft-hold refreshed on ${gh_repo}"
        else
          gh api --method PUT "repos/${gh_repo}/contents/${ics_path}" -f message="ops: soft-hold refresh HERMES-APPROVE-TAILSCALE.ics (#134)" -f content="$ics_b64" -f branch=main >/dev/null 2>&1 && echo "OK tip HERMES-APPROVE-TAILSCALE.ics soft-hold refreshed on ${gh_repo}"
        fi
      elif [[ -n "$tip_tok" ]] && command -v curl >/dev/null 2>&1; then
        ics_api="https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${ics_path}"
        ics_payload="$(ICS_B64="$ics_b64" ICS_SHA="$ics_sha" python3 -c 'import json,os; d={"message":"ops: soft-hold refresh HERMES-APPROVE-TAILSCALE.ics (#134)","content":os.environ["ICS_B64"],"branch":"main"}; s=os.environ.get("ICS_SHA") or "";
print(json.dumps({**d, **({"sha":s} if s else {})}))')"
        curl -fsS -X PUT -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"           -H "Content-Type: application/json" --data "$ics_payload" "$ics_api" >/dev/null 2>&1 && echo "OK tip HERMES-APPROVE-TAILSCALE.ics soft-hold refreshed on ${gh_repo} (curl)"
      fi
    fi
  fi
  # Best-effort auto-beacon when AuthURL changes (dedupe by URL).
  # Order: gh CLI → curl+GitHub token → Linear comment (RAL-823 by default).
  # Skips when none work — agent MCP can still post.
  if [[ "${HERMES_AUTHURL_GITHUB_BEACON:-1}" == "1" || "${HERMES_AUTHURL_LINEAR_BEACON:-1}" == "1" ]]; then
    if [[ ! -f "$lastfile" ]] || ! grep -qF "$url" "$lastfile" 2>/dev/null; then
      local body posted=0
      body="## Fresh Tailscale AuthURL (auto-beacon)

Approve NOW: ${url}

After approve, add Runtime Secrets \`HERMES_HOST_SSH_PRIVATE_KEY\` + \`LINEAR_API_KEY\` (waiters keep looping until SSH arrives).

Or Mac ONE-SHOT: \`curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command\`"
      if [[ "${HERMES_AUTHURL_GITHUB_BEACON:-1}" == "1" ]]; then
        if command -v gh >/dev/null 2>&1; then
          if gh issue comment "$gh_issue" --repo "$gh_repo" --body "$body" >/dev/null 2>&1; then
            posted=1
          fi
        fi
        if [[ "$posted" != "1" ]]; then
          local tok owner name api_url payload
          tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
          owner="${gh_repo%%/*}"
          name="${gh_repo#*/}"
          api_url="https://api.github.com/repos/${owner}/${name}/issues/${gh_issue}/comments"
          if [[ -n "$tok" && ! -f "${SCRIPT_DIR}/GH_TOKEN_INVALID.flag" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            _code="$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${tok}" -H "Accept: application/vnd.github+json" https://api.github.com/rate_limit 2>/dev/null || echo 000)"
            if [[ "$_code" == "401" || "$_code" == "403" ]]; then
              echo "$_code $(date -u +%FT%TZ)" >"${SCRIPT_DIR}/GH_TOKEN_INVALID.flag"
              echo "WARN GH_TOKEN unusable (HTTP ${_code}) — skip curl beacon"
              tok=""
            fi
          fi
          if [[ -n "$tok" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            payload="$(AUTHURL_BEACON_BODY="$body" python3 -c 'import json,os; print(json.dumps({"body": os.environ["AUTHURL_BEACON_BODY"]}))')"
            if curl -fsS -X POST \
              -H "Authorization: Bearer ${tok}" \
              -H "Accept: application/vnd.github+json" \
              -H "X-GitHub-Api-Version: 2022-11-28" \
              -H "Content-Type: application/json" \
              --data "$payload" \
              "$api_url" >/dev/null 2>&1; then
              posted=1
            fi
          fi
        fi
        if [[ "$posted" == "1" ]]; then
          echo "OK AuthURL GitHub beacon posted to ${gh_repo}#${gh_issue}"
        fi
        # Keep tip CURRENT_AUTHURL.md in sync so Mac ONE-SHOT (#92) opens the live URL.
        if [[ "${HERMES_AUTHURL_TIP_FILE:-1}" == "1" ]]; then
          local tip_path="CURRENT_AUTHURL.md" tip_body tip_sha tip_b64 tip_tok tip_owner tip_name tip_api tip_payload tip_put
          tip_body="# Live cloud Tailscale AuthURL

**Last refreshed:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Approve:** ${url}

Do **not** use older AuthURLs. Prefer Mac ONE-SHOT if Runtime Secrets stay unset.

After approve, cloud still needs \`HERMES_HOST_SSH_PRIVATE_KEY\` (+ preferably \`LINEAR_API_KEY\` / \`TS_AUTHKEY\`) unless Mac ONE-SHOT completes Downstream DONE.

Hostname to approve: \`cursor-cloud-hermes\`

Admin: https://login.tailscale.com/admin/machines
"
          tip_tok="${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
          tip_owner="${gh_repo%%/*}"
          tip_name="${gh_repo#*/}"
          if [[ -n "$tip_tok" && -f "${SCRIPT_DIR}/GH_TOKEN_INVALID.flag" ]]; then
            tip_tok=""
          elif [[ -n "$tip_tok" ]] && command -v curl >/dev/null 2>&1; then
            _code="$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json" https://api.github.com/rate_limit 2>/dev/null || echo 000)"
            if [[ "$_code" == "401" || "$_code" == "403" ]]; then
              echo "$_code $(date -u +%FT%TZ)" >"$