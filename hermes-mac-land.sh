#!/usr/bin/env bash
# Public bootstrap for Hermes Mac land.
# Paste ONE LINE on Mac Hermes (Tailscale up):
#   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
#
# Fetches private moltbot tip via gh (preferred) or git, then runs Mac apply-watch.
# No Slack rockets. Do not open private GitHub blob URLs in a browser.
set -euo pipefail

CLONE="${HERMES_MOLTBOT_CLONE:-/tmp/moltbot-main-tip-src}"
OWNER_REPO="ilike4movies/moltbot"

_notify() {
  local title="$1" msg="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
  fi
  echo "== $title: $msg =="
}

_fetch_tip() {
  rm -rf "$CLONE"
  if command -v gh >/dev/null 2>&1; then
    echo "Fetching tip via gh api tarball…"
    local extract="/tmp/moltbot-tarball-extract-$$"
    rm -rf "$extract"
    mkdir -p "$extract"
    if gh api "repos/$OWNER_REPO/tarball/main" | tar -xz -C "$extract"; then
      local inner
      inner="$(find "$extract" -mindepth 1 -maxdepth 1 -type d | head -1)"
      if [[ -n "$inner" && -d "$inner/shared-scripts" ]]; then
        mv "$inner" "$CLONE"
        rm -rf "$extract"
        echo "OK tip via gh tarball → $CLONE"
        return 0
      fi
    fi
    rm -rf "$extract"
  fi
  echo "WARN: gh tarball failed; trying git SSH"
  if git clone --depth 1 --branch main --single-branch \
      "git@github.com:${OWNER_REPO}.git" "$CLONE"; then
    echo "OK tip via git SSH → $CLONE"
    return 0
  fi
  rm -rf "$CLONE"
  echo "WARN: SSH clone failed; trying HTTPS"
  if git clone --depth 1 --branch main --single-branch \
      "https://github.com/${OWNER_REPO}.git" "$CLONE"; then
    echo "OK tip via HTTPS → $CLONE"
    return 0
  fi
  return 1
}

_notify "Hermes UNBLOCK" "Public curl bootstrap starting…"

if ! _fetch_tip; then
  _notify "Hermes UNBLOCK FAILED" "Could not fetch moltbot tip (need: gh auth login, or git SSH/HTTPS)"
  echo "ERROR: fetch tip failed. Run: gh auth login" >&2
  exit 1
fi

INSTALL="$CLONE/shared-scripts/install-hermes-moltbot-mac-apply-watch.sh"
if [[ ! -f "$INSTALL" ]]; then
  _notify "Hermes UNBLOCK FAILED" "Tip missing install-hermes-moltbot-mac-apply-watch.sh"
  exit 1
fi

_notify "Hermes UNBLOCK" "Running Mac apply-watch (via-ssh → grok-cos-1)…"
if bash "$INSTALL"; then
  _notify "Hermes UNBLOCK OK" "Expect Linear Host surgical-apply OK"
  echo "OK hermes-mac-land finished"
  exit 0
fi
RC=$?
_notify "Hermes UNBLOCK FAILED" "install exited $RC — check Tailscale + SSH to grok-cos-1"
exit "$RC"
