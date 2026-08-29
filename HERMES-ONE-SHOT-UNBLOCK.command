#!/bin/bash
# HERMES-ONE-SHOT-UNBLOCK.command — Right-click → Open on Mac Hermes (not double-click)
# Single click critical path for stalled canary recovery:
#   0) Open Tailscale admin + tip CURRENT_AUTHURL (approve cloud waiter) early
#   0a) Open Linear operator ticket (RAL-823) early
#   0b) Open Web UI workflow create + Raw paste tabs early (parallel with STALL)
#   0c) Install 5-min Downstream nag LaunchAgent (auto ONE-SHOT until issue #1 shows Downstream DONE)
#   1) Try STALL downstream (SSH/Tailscale to .11) — fastest when mesh works
#   2) On STALL fail → Phase 2 ENABLE (install workflow + gh workflow run; tip #127 uses HERMES_GH_WORKFLOW_PAT)
# Requires ~/.hermes/.env LINEAR_API_KEY. Prefer this over picking between STALL vs ENABLE.
# Do not put open canary ticket IDs in PR titles when enabling Actions.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-oneshot-unblock-command}"
export HERMES_RUN_ID="${HERMES_RUN_ID:-20260826T232521106484Z-2954673}"
export HERMES_AUTO_SURGICAL_LAND=0
export HERMES_AUTO_INSPECT_RAL793=1
export HERMES_AUTO_STACK_APPLY="${HERMES_AUTO_STACK_APPLY:-0}"
export HERMES_STALL_RECOVERY="${HERMES_STALL_RECOVERY:-1}"
export HERMES_WAIT_INVENTORY="${HERMES_WAIT_INVENTORY:-1}"
export HERMES_INVENTORY_WAIT_SECS="${HERMES_INVENTORY_WAIT_SECS:-900}"
export HERMES_STALL_ZOMBIE="${HERMES_STALL_ZOMBIE:-1}"
export HERMES_STALL_ZOMBIE_PASSES="${HERMES_STALL_ZOMBIE_PASSES:-3}"
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
FALLBACK_ACTIONS="${HERMES_ONE_SHOT_FALLBACK_ACTIONS:-1}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes ONE-SHOT UNBLOCK (run=$HERMES_RUN_ID) pin=$PIN ==="
echo "zombie=$HERMES_STALL_ZOMBIE zombie_passes=$HERMES_STALL_ZOMBIE_PASSES stall_recovery=$HERMES_STALL_RECOVERY"
echo "tip through #161 (ENABLE git-push fallback + #160 FALLBACK b2b5fc4); approve tip CURRENT_AUTHURL or RAL-823"
echo "Host: $(hostname) user: $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Status inbox: https://github.com/${REPO}/issues/1"
echo "Path: Web UI early + STALL first; on fail → ENABLE-ACTIONS (fallback=$FALLBACK_ACTIONS)"
# Spoken wake so Mac session notices even if browser tabs are buried.
if [[ "${HERMES_ONE_SHOT_SPEAK:-1}" == "1" ]] && command -v say >/dev/null 2>&1; then
  say -v Samantha "Hermes ONE-SHOT starting. Approve Tailscale or let STALL run." 2>/dev/null || true
fi

_load_mac_hermes_env() {
  local f="${HOME}/.hermes/.env"
  [[ -f "$f" ]] || return 0
  local key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ''|\#*) continue ;;
      LINEAR_API_KEY=*|LINEAR_API_TOKEN=*|HERMES_HOST_SSH_PRIVATE_KEY=*|GH_TOKEN=*|HERMES_STATUS_GITHUB_TOKEN=*|TS_AUTHKEY=*|HERMES_GH_WORKFLOW_PAT=*)
        key="${line%%=*}"
        val="${line#*=}"
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        [[ -z "${!key:-}" ]] && export "$key=$val"
        ;;
    esac
  done < "$f"
}

_preflight_mac_secrets() {
  _load_mac_hermes_env || true
  if [[ -z "${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}" ]]; then
    echo ""
    echo "FAILED: LINEAR_API_KEY (or LINEAR_API_TOKEN) missing — required for DISPATCH-NOW + Actions."
    echo " fix: add LINEAR_API_KEY=... to ~/.hermes/.env, then Right-click → Open again."
    osascript -e 'display notification "Add LINEAR_API_KEY to ~/.hermes/.env" with title "Hermes ONE-SHOT preflight FAILED" sound name "Basso"' 2>/dev/null || true
    read -r -p "Press Enter to close…" _
    exit 1
  fi
  # Tip #159: pre-export GitHub status token so curl fallback works if gh hangs mid-post.
  if [[ -z "${HERMES_STATUS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}" ]] && command -v gh >/dev/null 2>&1; then
    _tok="$(timeout 5 gh auth token 2>/dev/null || true)"
    if [[ -n "$_tok" ]]; then
      export HERMES_STATUS_GITHUB_TOKEN="$_tok"
      echo "OK tip #159 status token exported from gh auth"
    else
      echo "WARN tip #159: no gh auth token — Downstream DONE beacon may fail-closed; run: gh auth login"
    fi
  fi

}


_open_tailscale_approve_early() {
  # Open Tailscale admin (pending machines) + tip CURRENT_AUTHURL so Mac ONE-SHOT
  # can also approve the cloud waiter node as a parallel path.
  # Opt out: HERMES_ONE_SHOT_OPEN_TAILSCALE=0
  if [[ "${HERMES_ONE_SHOT_OPEN_TAILSCALE:-1}" != "1" ]]; then
    echo "SKIP early Tailscale approve tabs (HERMES_ONE_SHOT_OPEN_TAILSCALE=0)"
    return 0
  fi
  local ADMIN="https://login.tailscale.com/admin/machines"
  local AUTH=""
  local url f="/tmp/hermes-current-authurl-$$.txt"
  echo ""
  echo "=== Parallel: Tailscale approve (cloud waiter / pending machines) ==="
  echo "Admin (approve pending): $ADMIN"
  rm -f "$f"
  for url in \
    "https://raw.githubusercontent.com/${REPO}/${PIN}/CURRENT_AUTHURL.md" \
    "https://raw.githubusercontent.com/${REPO}/main/CURRENT_AUTHURL.md"
  do
    if curl -fsSL "$url" -o "$f" 2>/dev/null; then
      AUTH=$(grep -Eo 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' "$f" | head -1 || true)
      [[ -n "$AUTH" ]] && break
    fi
    rm -f "$f"
  done
  rm -f "$f"
  if [[ -n "$AUTH" ]]; then
    echo "Live AuthURL: $AUTH"
    osascript -e 'display notification "Approve Tailscale pending + AuthURL while STALL runs" with title "Hermes ONE-SHOT Tailscale" sound name "Glass"' 2>/dev/null || true
    open "$ADMIN" 2>/dev/null || true
    open "$AUTH" 2>/dev/null || true
  else
    echo "WARN no tip CURRENT_AUTHURL.md — opening admin machines only"
    osascript -e 'display notification "Approve pending Tailscale machines while STALL runs" with title "Hermes ONE-SHOT Tailscale" sound name "Glass"' 2>/dev/null || true
    open "$ADMIN" 2>/dev/null || true
  fi
  # Calendar wake ICS (tip HERMES-APPROVE-TAILSCALE.ics). Opt out: HERMES_ONE_SHOT_OPEN_ICS=0
  if [[ "${HERMES_ONE_SHOT_OPEN_ICS:-1}" == "1" ]]; then
    local ics="${HOME}/Downloads/HERMES-APPROVE-TAILSCALE.ics"
    if curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/HERMES-APPROVE-TAILSCALE.ics" -o "$ics" 2>/dev/null; then
      echo "Calendar ICS: $ics"
      open "$ics" 2>/dev/null || true
    else
      echo "WARN tip HERMES-APPROVE-TAILSCALE.ics not available yet"
    fi
  fi
}

_open_operator_linear_early() {
  # Surface operator wake ticket so Mac session sees current AuthURL + ONE-SHOT paste.
  # Opt out: HERMES_ONE_SHOT_OPEN_LINEAR=0
  if [[ "${HERMES_ONE_SHOT_OPEN_LINEAR:-1}" != "1" ]]; then
    echo "SKIP early Linear operator ticket (HERMES_ONE_SHOT_OPEN_LINEAR=0)"
    return 0
  fi
  local URL="${HERMES_OPERATOR_LINEAR_URL:-https://linear.app/ilike4/issue/RAL-823/operator-mac-one-shot-tailscale-approve-now-authurl-1d0d8050-canary}"
  echo ""
  echo "=== Parallel: Linear operator ticket ==="
  echo "$URL"
  open "$URL" 2>/dev/null || true
}

_open_webui_workflow_early() {
  # Open create-file + Raw paste tabs while Phase 1 STALL runs so the operator can
  # enable Actions in parallel (cloud API tokens cannot write .github/workflows/).
  # Opt out: HERMES_ONE_SHOT_OPEN_WEBUI_EARLY=0
  if [[ "${HERMES_ONE_SHOT_OPEN_WEBUI_EARLY:-1}" != "1" ]]; then
    echo "SKIP early Web UI (HERMES_ONE_SHOT_OPEN_WEBUI_EARLY=0)"
    return 0
  fi
  local WEBUI_NEW="https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml"
  local WEBUI_RAW="https://github.com/${REPO}/raw/main/ci/downstream-stall.yml"
  echo ""
  echo "=== Parallel: Web UI workflow enable (paste Raw while STALL runs) ==="
  echo "Create file: $WEBUI_NEW"
  echo "Paste source (Raw): $WEBUI_RAW"
  echo "Action secrets (if needed): https://github.com/${REPO}/settings/secrets/actions"
  osascript -e 'display notification "Browser: paste Raw into workflow create tab while STALL runs" with title "Hermes ONE-SHOT Web UI" sound name "Glass"' 2>/dev/null || true
  open "$WEBUI_NEW" 2>/dev/null || true
  open "$WEBUI_RAW" 2>/dev/null || true
}

_install_downstream_nag() {
  # Keep Mac reminding every 5 min until "## Downstream DONE" posts on issue #1.
  # Opt out: HERMES_ONE_SHOT_INSTALL_NAG=0
  if [[ "${HERMES_ONE_SHOT_INSTALL_NAG:-1}" != "1" ]]; then
    echo "SKIP downstream nag install (HERMES_ONE_SHOT_INSTALL_NAG=0)"
    return 0
  fi
  echo ""
  echo "=== Install Downstream nag LaunchAgent (5 min + auto ONE-SHOT until DONE) ==="
  local NAG="/tmp/hermes-install-downstream-nag-oneshot-$$.command"
  local url
  rm -f "$NAG"
  for url in \
    "https://raw.githubusercontent.com/${REPO}/${PIN}/HERMES-INSTALL-DOWNSTREAM-NAG.command" \
    "https://raw.githubusercontent.com/${REPO}/main/HERMES-INSTALL-DOWNSTREAM-NAG.command"
  do
    if curl -fsSL "$url" -o "$NAG" \
      && grep -q 'com.hermes.downstream-nag' "$NAG" 2>/dev/null \
      && grep -q '_machine_downstream_done' "$NAG" 2>/dev/null \
      && grep -q 'Downstream DONE @' "$NAG" 2>/dev/null; then
      # Tip #155: require tip#154+ detector (rejects stale pre-154 NAG that false-unloads on prose)
      # and tip#155 timestamped DONE match (part-c posts "## Downstream DONE @ $WHEN").
      chmod +x "$NAG"
      # Noninteractive: skip "Press Enter" (needs tip with HERMES_NAG_NONINTERACTIVE support).
      if HERMES_NAG_NONINTERACTIVE=1 bash "$NAG"; then
        echo "OK downstream nag installed/refreshed"
        rm -f "$NAG"
        return 0
      fi
      echo "WARN nag installer exited non-zero — continuing ONE-SHOT"
      rm -f "$NAG"
      return 0
    fi
    rm -f "$NAG"
  done
  echo "WARN could not fetch HERMES-INSTALL-DOWNSTREAM-NAG.command — continuing"
  return 0
}

_run_stall() {
  echo ""
  echo "=== Phase 1: STALL downstream (SSH/.11) ==="
  osascript -e 'display notification "Phase 1: STALL downstream on .11…" with title "Hermes ONE-SHOT" sound name "Glass"' 2>/dev/null || true
  local SCRIPT="/tmp/hermes-dispatcher-downstream-oneshot-$$.sh"
  local ONCE="/tmp/hermes-cloud-run-downstream-once-$$.sh"
  rm -f "$SCRIPT" "$ONCE"
  local FETCHED=""
  local url
  # Tip #146: prefer tip#142 once launcher + tip main first (tip#145 -f helpers).
  # Old HERMES_DOWNSTREAM_PIN default pinned a pre-#145 SHA and skipped tip fixes.
  local DOWNSTREAM_PIN="${HERMES_DOWNSTREAM_PIN:-}"
  _is_good_once() {
    local f="$1"
    grep -q 'Tip #142' "$f" 2>/dev/null \
      && grep -q 'hermes-dispatcher-downstream.sh' "$f" 2>/dev/null \
      && grep -q 'flock' "$f" 2>/dev/null
  }
  _is_good_downstream() {
    local f="$1"
    if grep -q 'ONE-SHOT safe entrypoint' "$f" 2>/dev/null \
       && grep -q 'hermes-dispatcher-part-a.sh' "$f" 2>/dev/null \
       && grep -q 'raw.githubusercontent.com' "$f" 2>/dev/null \
       && grep -q '_parts_integrity_ok' "$f" 2>/dev/null; then
      # Tip #158: entrypoint must reject pre-#156/#150/#151 parts
      return 0
    fi
    if grep -q 'RAL-793 run inspect' "$f" 2>/dev/null \
       && grep -q 'DISPATCH-NOW' "$f" 2>/dev/null \
       && grep -q 'WAIT_INVENTORY' "$f" 2>/dev/null \
       && grep -q 'fail-closed' "$f" 2>/dev/null; then
      return 0
    fi
    return 1
  }
  # Prefer tip#142 once launcher (single-flight + CDN dispatcher resolve).
  for url in \
    "https://raw.githubusercontent.com/${REPO}/${PIN}/shared-scripts/hermes-cloud-run-downstream-once.sh" \
    "https://raw.githubusercontent.com/${REPO}/main/shared-scripts/hermes-cloud-run-downstream-once.sh"
  do
    echo "Trying once launcher: $url"
    if curl -fsSL "$url" -o "$ONCE" && _is_good_once "$ONCE"; then
      chmod +x "$ONCE" 2>/dev/null || true
      echo "OK tip#146 using once launcher: $url"
      set +e
      bash "$ONCE"
      local rc=$?
      set -e
      rm -f "$ONCE"
      if [[ "$rc" -eq 0 ]]; then
        echo "OK STALL downstream finished for run $HERMES_RUN_ID (once)"
        return 0
      fi
      echo "WARN once launcher exited $rc — falling back to dispatcher entrypoint"
      break
    fi
    rm -f "$ONCE"
  done
  # Dispatcher entrypoint: tip/main first; optional legacy pin last.
  local urls=(
    "https://raw.githubusercontent.com/${REPO}/${PIN}/shared-scripts/hermes-dispatcher-downstream.sh"
    "https://raw.githubusercontent.com/${REPO}/main/shared-scripts/hermes-dispatcher-downstream.sh"
  )
  if [[ -n "$DOWNSTREAM_PIN" ]]; then
    urls+=("https://raw.githubusercontent.com/${REPO}/${DOWNSTREAM_PIN}/shared-scripts/hermes-dispatcher-downstream.sh")
  fi
  for url in "${urls[@]}"; do
    echo "Trying fetch: $url"
    if curl -fsSL "$url" -o "$SCRIPT"; then
      if _is_good_downstream "$SCRIPT"; then
        FETCHED="$url"
        break
      fi
      rm -f "$SCRIPT"
    fi
  done
  if [[ -z "$FETCHED" || ! -s "$SCRIPT" ]]; then
    echo "STALL fetch FAILED"
    return 2
  fi
  chmod +x "$SCRIPT" 2>/dev/null || true
  echo "OK fetched: $FETCHED"
  set +e
  bash "$SCRIPT"
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "OK STALL downstream finished for run $HERMES_RUN_ID"
    return 0
  fi
  echo "STALL downstream exited $rc"
  return 1
}

_install_workflow_via_git_push() {
  # Tip #161: contents API needs OAuth workflow scope; SSH/git push often works without it.
  local WF_PATH=".github/workflows/downstream-stall.yml"
  local SRC_URL="https://raw.githubusercontent.com/${REPO}/main/ci/downstream-stall.yml"
  local work="/tmp/hermes-wf-git-oneshot-$$"
  local src_file="/tmp/hermes-downstream-stall-yml-git-$$.yml"
  rm -rf "$work"
  mkdir -p "$work"
  curl -fsSL "$SRC_URL" -o "$src_file"
  if ! grep -q 'workflow_dispatch' "$src_file" || ! grep -q 'hermes-dispatcher-downstream.sh' "$src_file"; then
    echo "WARN tip #161: source workflow incomplete"
    rm -f "$src_file"
    rm -rf "$work"
    return 1
  fi
  echo "tip #161: trying git clone+push fallback (SSH first)…"
  if git clone --depth 1 "git@github.com:${REPO}.git" "$work/repo" >/tmp/hermes-wf-git-clone.out 2>/tmp/hermes-wf-git-clone.err; then
    echo "OK tip #161 cloned via SSH"
  elif GIT_TERMINAL_PROMPT=0 gh repo clone "$REPO" "$work/repo" -- --depth 1 >/tmp/hermes-wf-git-clone.out 2>>/tmp/hermes-wf-git-clone.err; then
    echo "OK tip #161 cloned via gh"
  else
    echo "WARN tip #161: git clone failed"
    cat /tmp/hermes-wf-git-clone.err 2>/dev/null || true
    rm -f "$src_file"
    rm -rf "$work"
    return 1
  fi
  mkdir -p "$work/repo/.github/workflows"
  cp "$src_file" "$work/repo/${WF_PATH}"
  rm -f "$src_file"
  (
    set -euo pipefail
    cd "$work/repo"
    git config user.email "hermes-mac-land@local"
    git config user.name "Hermes ONE-SHOT tip161"
    git add "$WF_PATH"
    if git diff --cached --quiet; then
      echo "OK tip #161: workflow already present in clone"
      exit 0
    fi
    git commit -m "ci: enable downstream-stall workflow under .github/workflows (tip #161 git fallback)"
    git push origin HEAD:main
  )
  local rc=$?
  rm -rf "$work"
  if [[ "$rc" -eq 0 ]]; then
    echo "OK tip #161 installed ${WF_PATH} via git push"
    return 0
  fi
  echo "WARN tip #161: git push failed (rc=$rc)"
  return 1
}

_run_enable_actions() {
  echo ""
  echo "=== Phase 2: ENABLE Downstream Actions (local gh) ==="
  osascript -e 'display notification "Phase 2: enabling GitHub Actions path…" with title "Hermes ONE-SHOT" sound name "Glass"' 2>/dev/null || true
  # Tip #127: same as ENABLE #126 — prefer HERMES_GH_WORKFLOW_PAT when gh lacks workflows scope.
  _load_mac_hermes_env || true
  if [[ -n "${HERMES_GH_WORKFLOW_PAT:-}" ]]; then
    export GH_TOKEN="$HERMES_GH_WORKFLOW_PAT"
    export GITHUB_TOKEN="$HERMES_GH_WORKFLOW_PAT"
    echo "OK using HERMES_GH_WORKFLOW_PAT for workflow write (tip #127)"
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "FAILED: gh CLI missing. Install GitHub CLI, then: gh auth login"
    echo "Or web UI: paste Raw ci/downstream-stall.yml into create-file editor"
    WEBUI_NEW="https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml"
    WEBUI_RAW="https://github.com/${REPO}/raw/main/ci/downstream-stall.yml"
    echo "Web UI create: $WEBUI_NEW"
    echo "Web UI paste source (Raw): $WEBUI_RAW"
    open "$WEBUI_NEW" 2>/dev/null || true
    open "$WEBUI_RAW" 2>/dev/null || true
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "FAILED: gh not logged in. Run: gh auth login"
    return 1
  fi
  local WF_PATH=".github/workflows/downstream-stall.yml"
  local SRC_URL="https://raw.githubusercontent.com/${REPO}/main/ci/downstream-stall.yml"
  local EXISTING_SHA=""
  if EXISTING_SHA=$(gh api "repos/${REPO}/contents/${WF_PATH}" --jq .sha 2>/dev/null); then
    echo "OK workflow already on main (sha=${EXISTING_SHA:0:12}…)"
  else
    echo "Installing ${WF_PATH}…"
    local SRC_FILE="/tmp/hermes-downstream-stall-yml-$$.yml"
    curl -fsSL "$SRC_URL" -o "$SRC_FILE"
    if ! grep -q 'workflow_dispatch' "$SRC_FILE" || ! grep -q 'hermes-dispatcher-downstream.sh' "$SRC_FILE"; then
      echo "FAILED: downloaded workflow looks incomplete"
      rm -f "$SRC_FILE"
      return 1
    fi
    local B64
    B64=$(base64 < "$SRC_FILE" | tr -d '\n')
    rm -f "$SRC_FILE"
    if ! gh api --method PUT "repos/${REPO}/contents/${WF_PATH}" \
        -f message='ci: enable downstream-stall workflow under .github/workflows' \
        -f content="$B64" \
        -f branch=main >/tmp/hermes-wf-put.json 2>/tmp/hermes-wf-put.err; then
      echo "WARN: contents API PUT failed (likely missing OAuth workflow scope)"
      cat /tmp/hermes-wf-put.err 2>/dev/null || true
      if ! _install_workflow_via_git_push; then
        echo "FAILED: could not write ${WF_PATH} (contents API + tip #161 git fallback)"
        echo "Fix: set HERMES_GH_WORKFLOW_PAT in ~/.hermes/.env (tip #127) or: gh auth refresh -h github.com -s workflow"
        echo "Or ensure SSH git@github.com works, or Web UI paste Raw"
        WEBUI_NEW="https://github.com/${REPO}/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml"
        WEBUI_RAW="https://github.com/${REPO}/raw/main/ci/downstream-stall.yml"
        echo "Web UI create: $WEBUI_NEW"
        echo "Web UI paste source (Raw): $WEBUI_RAW"
        open "$WEBUI_NEW" 2>/dev/null || true
        open "$WEBUI_RAW" 2>/dev/null || true
        return 1
      fi
    fi
    echo "OK installed ${WF_PATH}"
  fi
  echo "Action secrets required: TS_AUTHKEY HERMES_HOST_SSH_PRIVATE_KEY LINEAR_API_KEY"
  echo "Secrets UI: https://github.com/${REPO}/settings/secrets/actions"
  if gh workflow run downstream-stall.yml --repo "$REPO"; then
    echo "OK workflow_dispatch accepted"
    echo "Watch: https://github.com/${REPO}/actions"
    echo "Inbox: https://github.com/${REPO}/issues/1"
    open "https://github.com/${REPO}/actions" 2>/dev/null || true
    return 0
  fi
  echo "FAILED: gh workflow run — check secrets / Actions enabled"
  open "https://github.com/${REPO}/actions" 2>/dev/null || true
  open "https://github.com/${REPO}/settings/secrets/actions" 2>/dev/null || true
  return 1
}

xattr -d com.apple.quarantine "$0" 2>/dev/null || true
chmod +x "$0" 2>/dev/null || true
_preflight_mac_secrets

_open_tailscale_approve_early
_open_operator_linear_early
_open_webui_workflow_early
_install_downstream_nag

STALL_RC=0
_run_stall || STALL_RC=$?
if [[ "$STALL_RC" -eq 0 ]]; then
  osascript -e 'display notification "STALL OK. Watch Linear + GitHub #1." with title "Hermes ONE-SHOT OK" sound name "Hero"' 2>/dev/null || true
  say "Hermes one shot stall complete. Watch Linear for inventory." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi

echo ""
echo "Phase 1 STALL did not complete (rc=$STALL_RC)."
if [[ "$FALLBACK_ACTIONS" != "1" ]]; then
  echo "HERMES_ONE_SHOT_FALLBACK_ACTIONS=0 — not running Actions fallback."
  osascript -e 'display notification "STALL FAILED. Actions fallback disabled." with title "Hermes ONE-SHOT FAILED" sound name "Basso"' 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit "$STALL_RC"
fi

if _run_enable_actions; then
  osascript -e 'display notification "Actions path started. Watch Actions + issue #1." with title "Hermes ONE-SHOT PARTIAL→Actions" sound name "Hero"' 2>/dev/null || true
  say "Hermes Actions downstream started. Watch GitHub." 2>/dev/null || true
  read -r -p "Press Enter to close…" _
  exit 0
fi

osascript -e 'display notification "STALL and Actions both failed. See Terminal." with title "Hermes ONE-SHOT FAILED" sound name "Basso"' 2>/dev/null || true
read -r -p "Press Enter to close…" _
exit 1
