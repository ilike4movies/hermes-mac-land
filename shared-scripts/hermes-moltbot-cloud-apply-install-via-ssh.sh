#!/usr/bin/env bash
# hermes-moltbot-cloud-apply-install-via-ssh.sh - run tip install on grok-cos-1 from any Tailscale host
#
# For Mac Hermes / any machine already on the Tailscale mesh that can SSH to
# grok-cos-1. Cloud Cursor can use this after joining Tailscale (see
# hermes-moltbot-cloud-tailscale-join-and-apply.sh).
#
# Optional: HERMES_JUMP_SSH_PRIVATE_KEY (PEM contents) -> temp IdentityFile for BatchMode SSH.
#
# Usage (from Mac / Tailscale client):
#   bash shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
#   HERMES_JUMP_SSH=ilike4@100.92.147.61 bash shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
#   bash shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh --dry-run
#
# Prefer cloning tip main first if this file is not local yet:
#   git clone --depth 1 --branch main --single-branch \
#     git@github.com:ilike4movies/moltbot.git /tmp/moltbot-main-tip-src
#   bash /tmp/moltbot-main-tip-src/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
set -euo pipefail

JUMP_SSH="${HERMES_JUMP_SSH:-ilike4@100.92.147.61}"
REMOTE_URL="${HERMES_MOLTBOT_REMOTE:-git@github.com:ilike4movies/moltbot.git}"
HTTPS_URL="https://github.com/ilike4movies/moltbot.git"
CLONE_TIMEOUT_SEC="${HERMES_MOLTBOT_CLONE_TIMEOUT_SEC:-180}"
DRY_RUN=0
SSH_IDENTITY_ARGS=()
TMP_KEY=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BEACON="$SCRIPT_DIR/hermes-moltbot-land-beacon.sh"

cleanup() {
  if [[ -n "$TMP_KEY" && -f "$TMP_KEY" ]]; then
    rm -f "$TMP_KEY"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) JUMP_SSH="$2"; shift 2 ;;
    --remote-url) REMOTE_URL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '1,32p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" ]]; then
  TMP_KEY="$(mktemp /tmp/hermes-jump-ssh.XXXXXX)"
  printf '%s\n' "$HERMES_JUMP_SSH_PRIVATE_KEY" > "$TMP_KEY"
  chmod 600 "$TMP_KEY"
  SSH_IDENTITY_ARGS=(-i "$TMP_KEY" -o IdentitiesOnly=yes)
  echo "OK using HERMES_JUMP_SSH_PRIVATE_KEY IdentityFile"
fi

echo "== cloud-apply-install-via-ssh jump=$JUMP_SSH dry_run=$DRY_RUN clone_timeout=${CLONE_TIMEOUT_SEC}s =="

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would ssh $JUMP_SSH, clone tip main, run install-hermes-moltbot-cloud-apply-signal-watch.sh"
  exit 0
fi

# Best-effort STARTED (covers Terminal + any Tailscale client, not only .command).
if [[ -f "$BEACON" ]]; then
  bash "$BEACON" started --source cloud-apply-install-via-ssh || true
fi

set +e
# shellcheck disable=SC2029
ssh -o BatchMode=yes -o ConnectTimeout=20 \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
  "${SSH_IDENTITY_ARGS[@]}" "$JUMP_SSH" \
  env HERMES_MOLTBOT_REMOTE="$REMOTE_URL" HERMES_MOLTBOT_CLONE_TIMEOUT_SEC="$CLONE_TIMEOUT_SEC" bash -s <<'REMOTE'
set -euo pipefail
REMOTE_URL="${HERMES_MOLTBOT_REMOTE:-git@github.com:ilike4movies/moltbot.git}"
HTTPS_URL="https://github.com/ilike4movies/moltbot.git"
CLONE="/tmp/moltbot-main-tip-src"
CLONE_TIMEOUT_SEC="${HERMES_MOLTBOT_CLONE_TIMEOUT_SEC:-180}"
export GIT_TERMINAL_PROMPT=0

_clone_with_timeout() {
  local url="$1" dest="$2"
  rm -rf "$dest"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CLONE_TIMEOUT_SEC" git clone --depth 1 --branch main --single-branch "$url" "$dest"
  else
    # No GNU timeout: background + wait (best-effort hang guard).
    git clone --depth 1 --branch main --single-branch "$url" "$dest" &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
      i=$((i + 1))
      if [[ "$i" -ge "$CLONE_TIMEOUT_SEC" ]]; then
        echo "WARN: clone timed out after ${CLONE_TIMEOUT_SEC}s; killing pid=$pid"
        kill "$pid" 2>/dev/null || true
        sleep 1
        kill -9 "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        return 124
      fi
      sleep 1
    done
    wait "$pid"
  fi
}

# Clear any prior hung clone dir/process residue.
pkill -f "git clone .*moltbot.*${CLONE}" 2>/dev/null || true
rm -rf "$CLONE"

if ! _clone_with_timeout "$REMOTE_URL" "$CLONE"; then
  echo "WARN: SSH clone failed/timed out; trying HTTPS (timeout ${CLONE_TIMEOUT_SEC}s)"
  if ! _clone_with_timeout "$HTTPS_URL" "$CLONE"; then
    echo "ERROR: both SSH and HTTPS tip clones failed/timed out" >&2
    exit 1
  fi
fi
bash "$CLONE/shared-scripts/install-hermes-moltbot-cloud-apply-signal-watch.sh"
REMOTE
RC=$?
set -e

if [[ "$RC" -ne 0 ]]; then
  if [[ -f "$BEACON" ]]; then
    bash "$BEACON" failed --source cloud-apply-install-via-ssh --detail "ssh/remote install exited $RC jump=$JUMP_SSH" || true
  fi
  echo "ERROR: via-ssh install failed rc=$RC" >&2
  exit "$RC"
fi

echo "via-ssh install finished (expect OK INTERRUPT_LABEL hermes-now in remote output)"
exit 0
