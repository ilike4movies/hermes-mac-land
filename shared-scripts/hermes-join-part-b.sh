_refresh_authurl_file() {
  local url authfile="${SCRIPT_DIR}/CURRENT_AUTHURL.txt"
  local lastfile="${SCRIPT_DIR}/LAST_POSTED_AUTHURL.txt"
  local gh_repo="${HERMES_STATUS_GITHUB_REPO:-ilike4movies/hermes-mac-land}"
  local gh_issue="${HERMES_STATUS_GITHUB_ISSUE:-1}"
  local linear_ticket="${HERMES_AUTHURL_LINEAR_ISSUE:-RAL-823}"
  reload_cloud_secrets || true
  url="$(ts status 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[a-z0-9]+' | head -1 || true)"
  [[ -n "$url" ]] || return 0
  if [[ ! -f "$authfile" ]] || ! grep -qF "$url" "$authfile" 2>/dev/null; then
    {
      printf '%s\n' "$url"
      printf 'ACTIVE — approve now (%s).\n' "$(date -u +%FT%TZ)"
      echo 'Cloud waiters armed; TS_AUTHKEY preferred. Proactive refresh before prior TTL.'
    } >"$authfile"
    echo "APPROVE_THIS_URL=$url"
    # Local marker for cloud agents (MCP) when gh tip write is unavailable.
    {
      printf '%s\n' "$url"
      printf 'refreshed=%s\n' "$(date -u +%FT%TZ)"
    } >"${SCRIPT_DIR}/PENDING_AUTHURL_TIP.txt"
    # Local ICS for agent MCP / Mac copies when tip gh write is unavailable.
    if command -v python3 >/dev/null 2>&1; then
      AUTHURL_ICS_URL="$url" python3 - <<'ICS' >"${SCRIPT_DIR}/HERMES-APPROVE-TAILSCALE.ics" 2>/dev/null || true
import os
from datetime import datetime, timedelta, timezone
url = os.environ["AUTHURL_ICS_URL"]
suffix = url.rstrip("/").rsplit("/", 1)[-1][:12]
now = datetime.now(timezone.utc)
dt = now.strftime("%Y%m%dT%H%M%SZ")
end = (now + timedelta(hours=2)).strftime("%Y%m%dT%H%M%SZ")
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
  # Best-effort auto-beacon when AuthURL changes (dedupe by URL).
  # Order: gh CLI → curl+GitHub token → Linear comment (RAL-823 by default).
  # Skips when none work — agent MCP can still post.
  if [[ "${HERMES_AUTHURL_GITHUB_BEACON:-1}" == "1" || "${HERMES_AUTHURL_LINEAR_BEACON:-1}" == "1" ]]; then
    if [[ ! -f "$lastfile" ]] || ! grep -qF "$url" "$lastfile" 2>/dev/null; then
      local body posted=0
      body="## Fresh Tailscale AuthURL (auto-beacon)

Approve NOW: ${url}

After approve, add Runtime Secrets \`HERMES_HOST_SSH_PRIVATE_KEY\` + \`LINEAR_API_KEY\` (waiters keep looping until SSH arrives).

Or Mac ONE-SHOT: \`curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command\`"
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
          tip_sha=""
          if command -v gh >/dev/null 2>&1; then
            tip_sha="$(gh api "repos/${gh_repo}/contents/${tip_path}" --jq .sha 2>/dev/null || true)"
          elif [[ -n "$tip_tok" ]] && command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
            tip_sha="$(curl -fsS -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"               "https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${tip_path}" 2>/dev/null               | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sha",""))' 2>/dev/null || true)"
          fi
          tip_b64="$(printf '%s' "$tip_body" | base64 | tr -d '\n')"
          if command -v gh >/dev/null 2>&1; then
            if [[ -n "$tip_sha" ]]; then
              tip_put=(gh api --method PUT "repos/${gh_repo}/contents/${tip_path}" -f message="ops: refresh CURRENT_AUTHURL.md" -f content="$tip_b64" -f branch=main -f sha="$tip_sha")
            else
              tip_put=(gh api --method PUT "repos/${gh_repo}/contents/${tip_path}" -f message="ops: refresh CURRENT_AUTHURL.md" -f content="$tip_b64" -f branch=main)
            fi
            if "${tip_put[@]}" >/dev/null 2>&1; then
              echo "OK tip CURRENT_AUTHURL.md refreshed on ${gh_repo}"
              posted=1
            fi
          elif [[ -n "$tip_tok" ]] && command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            tip_api="https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${tip_path}"
            tip_payload="$(TIP_B64="$tip_b64" TIP_SHA="$tip_sha" python3 -c 'import json,os; d={"message":"ops: refresh CURRENT_AUTHURL.md","content":os.environ["TIP_B64"],"branch":"main"}; s=os.environ.get("TIP_SHA") or "";
print(json.dumps({**d, **({"sha":s} if s else {})}))')"
            if curl -fsS -X PUT -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"               -H "Content-Type: application/json" --data "$tip_payload" "$tip_api" >/dev/null 2>&1; then
              echo "OK tip CURRENT_AUTHURL.md refreshed on ${gh_repo} (curl)"
              posted=1
            fi
          fi
          # Keep tip HERMES-APPROVE-TAILSCALE.ics in sync (#102 ONE-SHOT/nag calendar).
          if [[ "${HERMES_AUTHURL_TIP_ICS:-1}" == "1" ]] && command -v python3 >/dev/null 2>&1; then
            local ics_path="HERMES-APPROVE-TAILSCALE.ics" ics_body ics_sha ics_b64 ics_put ics_api ics_payload
            ics_body="$(AUTHURL_ICS_URL="$url" python3 - <<'ICS'
import os
from datetime import datetime, timedelta, timezone
url = os.environ["AUTHURL_ICS_URL"]
suffix = url.rstrip("/").rsplit("/", 1)[-1][:12]
now = datetime.now(timezone.utc)
dt = now.strftime("%Y%m%dT%H%M%SZ")
end = (now + timedelta(hours=2)).strftime("%Y%m%dT%H%M%SZ")
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
              ics_sha="$(curl -fsS -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"                 "https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${ics_path}" 2>/dev/null                 | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sha",""))' 2>/dev/null || true)"
            fi
            ics_b64="$(printf '%s' "$ics_body" | base64 | tr -d '\n')"
            if command -v gh >/dev/null 2>&1; then
              if [[ -n "$ics_sha" ]]; then
                ics_put=(gh api --method PUT "repos/${gh_repo}/contents/${ics_path}" -f message="ops: refresh HERMES-APPROVE-TAILSCALE.ics" -f content="$ics_b64" -f branch=main -f sha="$ics_sha")
              else
                ics_put=(gh api --method PUT "repos/${gh_repo}/contents/${ics_path}" -f message="ops: refresh HERMES-APPROVE-TAILSCALE.ics" -f content="$ics_b64" -f branch=main)
              fi
              if "${ics_put[@]}" >/dev/null 2>&1; then
                echo "OK tip HERMES-APPROVE-TAILSCALE.ics refreshed on ${gh_repo}"
                posted=1
              fi
            elif [[ -n "$tip_tok" ]] && command -v curl >/dev/null 2>&1; then
              ics_api="https://api.github.com/repos/${tip_owner}/${tip_name}/contents/${ics_path}"
              ics_payload="$(ICS_B64="$ics_b64" ICS_SHA="$ics_sha" python3 -c 'import json,os; d={"message":"ops: refresh HERMES-APPROVE-TAILSCALE.ics","content":os.environ["ICS_B64"],"branch":"main"}; s=os.environ.get("ICS_SHA") or "";
print(json.dumps({**d, **({"sha":s} if s else {})}))')"
              if curl -fsS -X PUT -H "Authorization: Bearer ${tip_tok}" -H "Accept: application/vnd.github+json"                 -H "Content-Type: application/json" --data "$ics_payload" "$ics_api" >/dev/null 2>&1; then
                echo "OK tip HERMES-APPROVE-TAILSCALE.ics refreshed on ${gh_repo} (curl)"
                posted=1
              fi
            fi
          fi
        fi
      fi
      if [[ "$posted" != "1" && "${HERMES_AUTHURL_LINEAR_BEACON:-1}" == "1" ]]; then
        local lkey="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
        if [[ -n "$lkey" ]] && command -v python3 >/dev/null 2>&1; then
          if LINEAR_KEY="$lkey" LINEAR_TICKET="$linear_ticket" AUTHURL_BEACON_BODY="$body" python3 - <<'PY' >/dev/null 2>&1
import json, os, urllib.request
key = os.environ["LINEAR_KEY"]
ticket = os.environ["LINEAR_TICKET"]
body = os.environ["AUTHURL_BEACON_BODY"]
q1 = {
    "query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id identifier}}}",
    "variables": {"q": ticket},
}
req = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q1).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
with urllib.request.urlopen(req, timeout=8) as r:
    nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
if not nodes:
    raise SystemExit(1)
iid = nodes[0]["id"]
q2 = {
    "query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
    "variables": {"id": iid, "b": body},
}
req2 = urllib.request.Request(
    "https://api.linear.app/graphql",
    data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key},
)
urllib.request.urlopen(req2, timeout=8).read()
print("ok")
PY
          then
            posted=1
            echo "OK AuthURL Linear beacon posted to ${linear_ticket}"
          fi
        fi
      fi
      if [[ "$posted" == "1" ]]; then
        printf '%s\n' "$url" >"$lastfile"
      else
        # Throttle skip warnings (wait loop polls every ~5s).
        local warnfile="${SCRIPT_DIR}/LAST_AUTHURL_BEACON_WARN.txt"
        local now warn_age=99999
        now="$(date +%s)"
        if [[ -f "$warnfile" ]]; then
          warn_age=$(( now - $(stat -c %Y "$warnfile" 2>/dev/null || echo 0) ))
        fi
        if (( warn_age >= ${HERMES_AUTHURL_BEACON_WARN_SECS:-60} )); then
          echo "WARN AuthURL beacon skipped (gh/token/Linear write unavailable)"
          printf '%s\n' "$url" >"$warnfile"
        fi
      fi
    fi
  fi
}

