#!/usr/bin/env bash
# hermes-moltbot-cloud-apply-install-via-ssh.sh - land tip from any Tailscale/LAN host
#
# Preferred: SSH → grok-cos-1 (jump clones tip + installs apply watch).
# Fallback: if jump BatchMode fails, SSH → .11 directly and run surgical-apply
# (Mac Hermes on home LAN / Tailscale can reach .11 even when jump is down).
#
# Optional: HERMES_JUMP_SSH_PRIVATE_KEY / HERMES_HOST_SSH_PRIVATE_KEY (PEM) for BatchMode.
#
# Usage:
#   bash shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
#   HERMES_JUMP_SSH=ilike4@100.92.147.61 bash shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
#   bash shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh --dry-run
set -euo pipefail

JUMP_SSH="${HERMES_JUMP_SSH:-ilike4@100.92.147.61}"
HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
REMOTE_URL="${HERMES_MOLTBOT_REMOTE:-git@github.com:ilike4movies/moltbot.git}"
HTTPS_URL="https://github.com/ilike4movies/moltbot.git"
CLONE_TIMEOUT_SEC="${HERMES_MOLTBOT_CLONE_TIMEOUT_SEC:-180}"
DRY_RUN=0
SSH_IDENTITY_ARGS=()
TMP_KEY=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BEACON="$SCRIPT_DIR/hermes-moltbot-land-beacon.sh"
ALLOW_DIRECT_HOST="${HERMES_ALLOW_DIRECT_HOST:-1}"

cleanup() {
  if [[ -n "$TMP_KEY" && -f "$TMP_KEY" ]]; then
    rm -f "$TMP_KEY"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) JUMP_SSH="$2"; shift 2 ;;
    --host-ssh) HOST_SSH="$2"; shift 2 ;;
    --remote-url) REMOTE_URL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-direct-host) ALLOW_DIRECT_HOST=0; shift ;;
    -h|--help)
      sed -n '1,36p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

_key_pem="${HERMES_JUMP_SSH_PRIVATE_KEY:-${HERMES_HOST_SSH_PRIVATE_KEY:-}}"
if [[ -n "$_key_pem" ]]; then
  TMP_KEY="$(mktemp /tmp/hermes-jump-ssh.XXXXXX)"
  printf '%s\n' "$_key_pem" > "$TMP_KEY"
  chmod 600 "$TMP_KEY"
  SSH_IDENTITY_ARGS=(-i "$TMP_KEY" -o IdentitiesOnly=yes)
  echo "OK using SSH IdentityFile from env"
fi

echo "== cloud-apply-install-via-ssh jump=$JUMP_SSH host=$HOST_SSH lan=$HOST_SSH_LAN dry_run=$DRY_RUN clone_timeout=${CLONE_TIMEOUT_SEC}s =="

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would try jump $JUMP_SSH, else direct host $HOST_SSH / $HOST_SSH_LAN"
  exit 0
fi

if [[ -f "$BEACON" ]]; then
  bash "$BEACON" started --source cloud-apply-install-via-ssh || true
fi

_ssh_ok() {
  local target="$1"
  ssh -o BatchMode=yes -o ConnectTimeout=12 \
    -o StrictHostKeyChecking=accept-new \
    "${SSH_IDENTITY_ARGS[@]}" "$target" 'echo OK_SSH; hostname' >/dev/null 2>&1
}

_run_on_jump() {
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
}

_run_on_host() {
  local target="$1"
  echo "== direct-host surgical-apply via $target =="
  # shellcheck disable=SC2029
  ssh -o BatchMode=yes -o ConnectTimeout=20 \
    -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
    "${SSH_IDENTITY_ARGS[@]}" "$target" \
    env HERMES_MOLTBOT_REMOTE="$REMOTE_URL" HERMES_MOLTBOT_CLONE_TIMEOUT_SEC="$CLONE_TIMEOUT_SEC" bash -s <<'REMOTE'
set -euo pipefail
REPO="${HERMES_MOLTBOT_REPO:-/opt/moltbot}"
REMOTE_URL="${HERMES_MOLTBOT_REMOTE:-git@github.com:ilike4movies/moltbot.git}"
HTTPS_URL="https://github.com/ilike4movies/moltbot.git"
CLONE="/tmp/moltbot-main-tip-src"
CLONE_TIMEOUT_SEC="${HERMES_MOLTBOT_CLONE_TIMEOUT_SEC:-180}"
export GIT_TERMINAL_PROMPT=0
cd "$REPO" || { echo "ERROR: missing $REPO" >&2; exit 1; }

_clone_with_timeout() {
  local url="$1" dest="$2"
  rm -rf "$dest"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CLONE_TIMEOUT_SEC" git clone --depth 1 --branch main --single-branch "$url" "$dest"
  else
    git clone --depth 1 --branch main --single-branch "$url" "$dest" &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
      i=$((i + 1))
      if [[ "$i" -ge "$CLONE_TIMEOUT_SEC" ]]; then
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

rm -rf "$CLONE"
if ! _clone_with_timeout "$REMOTE_URL" "$CLONE"; then
  echo "WARN: SSH clone failed/timed out; trying HTTPS"
  if ! _clone_with_timeout "$HTTPS_URL" "$CLONE"; then
    echo "ERROR: tip clone failed on host" >&2
    exit 1
  fi
fi
bash "$CLONE/shared-scripts/hermes-moltbot-surgical-apply.sh"
REMOTE
}

set +e
if _ssh_ok "$JUMP_SSH"; then
  echo "OK jump reachable: $JUMP_SSH"
  _run_on_jump
  RC=$?
else
  echo "WARN: jump unreachable ($JUMP_SSH); trying direct host fallback"
  RC=91
  if [[ "$ALLOW_DIRECT_HOST" == "1" ]]; then
    if _ssh_ok "$HOST_SSH"; then
      _run_on_host "$HOST_SSH"
      RC=$?
    elif _ssh_ok "$HOST_SSH_LAN"; then
      _run_on_host "$HOST_SSH_LAN"
      RC=$?
    else
      echo "ERROR: jump and direct host (.11 Tailscale + LAN) all unreachable" >&2
      RC=91
    fi
  fi
fi
set -e

if [[ "$RC" -ne 0 ]]; then
  if [[ -f "$BEACON" ]]; then
    bash "$BEACON" failed --source cloud-apply-install-via-ssh --detail "land exited $RC jump=$JUMP_SSH host=$HOST_SSH" || true
  fi
  echo "ERROR: via-ssh/direct-host install failed rc=$RC" >&2
  exit "$RC"
fi

echo "via-ssh/direct-host land finished (expect OK INTERRUPT_LABEL hermes-now in remote output)"
exit 0
