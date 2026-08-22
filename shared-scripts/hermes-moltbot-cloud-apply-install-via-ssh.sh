#!/usr/bin/env bash
# hermes-moltbot-cloud-apply-install-via-ssh.sh - land tip from any Tailscale/LAN host
#
# Preferred: SSH → grok-cos-1 (jump clones tip + installs apply watch).
# Fallback: if jump BatchMode fails, SSH → .11 directly and run surgical-apply
# (Mac Hermes on home LAN / Tailscale can reach .11 even when jump is down).
#
# Optional: HERMES_JUMP_SSH_PRIVATE_KEY / HERMES_HOST_SSH_PRIVATE_KEY (PEM) for BatchMode.
# Uses separate identity files when both keys are provided (jump vs direct .11).
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
JUMP_SSH_IDENTITY_ARGS=()
HOST_SSH_IDENTITY_ARGS=()
TMP_JUMP_KEY=""
TMP_HOST_KEY=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BEACON="$SCRIPT_DIR/hermes-moltbot-land-beacon.sh"
ALLOW_DIRECT_HOST="${HERMES_ALLOW_DIRECT_HOST:-1}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
JUMP_KEY_FILE="${HERMES_JUMP_SSH_KEY_FILE:-$KEY_DIR/jump-ssh-key}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"

cleanup() {
  [[ -n "$TMP_JUMP_KEY" && -f "$TMP_JUMP_KEY" ]] && rm -f "$TMP_JUMP_KEY"
  [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"
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
      sed -n '1,40p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

_write_keyfile() {
  local pem="$1"
  local f
  f="$(mktemp /tmp/hermes-ssh.XXXXXX)"
  printf '%s\n' "$pem" > "$f"
  chmod 600 "$f"
  echo "$f"
}

_load_jump_pem() {
  if [[ -n "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$HERMES_JUMP_SSH_PRIVATE_KEY"
    return 0
  fi
  if [[ -s "$JUMP_KEY_FILE" ]]; then
    cat "$JUMP_KEY_FILE"
    return 0
  fi
  return 1
}

_load_host_pem() {
  if [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY"
    return 0
  fi
  if [[ -s "$HOST_KEY_FILE" ]]; then
    cat "$HOST_KEY_FILE"
    return 0
  fi
  return 1
}

if _jump_pem="$(_load_jump_pem 2>/dev/null)"; then
  TMP_JUMP_KEY="$(_write_keyfile "$_jump_pem")"
  JUMP_SSH_IDENTITY_ARGS=(-i "$TMP_JUMP_KEY" -o IdentitiesOnly=yes)
  echo "OK jump SSH identity loaded"
fi
if _host_pem="$(_load_host_pem 2>/dev/null)"; then
  TMP_HOST_KEY="$(_write_keyfile "$_host_pem")"
  HOST_SSH_IDENTITY_ARGS=(-i "$TMP_HOST_KEY" -o IdentitiesOnly=yes)
  echo "OK host SSH identity loaded"
elif [[ ${#JUMP_SSH_IDENTITY_ARGS[@]} -gt 0 ]]; then
  HOST_SSH_IDENTITY_ARGS=("${JUMP_SSH_IDENTITY_ARGS[@]}")
  echo "OK host SSH identity falls back to jump key"
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
  shift
  local -a idargs=("$@")
  if [[ ${#idargs[@]} -gt 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=12 \
      -o StrictHostKeyChecking=accept-new \
      "${idargs[@]}" "$target" 'echo OK_SSH; hostname' >/dev/null 2>&1
  else
    ssh -o BatchMode=yes -o ConnectTimeout=12 \
      -o StrictHostKeyChecking=accept-new \
      "$target" 'echo OK_SSH; hostname' >/dev/null 2>&1
  fi
}

_run_on_jump() {
  local -a idargs=("$@")
  # shellcheck disable=SC2029
  if [[ ${#idargs[@]} -gt 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=20 \
      -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
      "${idargs[@]}" "$JUMP_SSH" \
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
  else
    ssh -o BatchMode=yes -o ConnectTimeout=20 \
      -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
      "$JUMP_SSH" \
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
  fi
}

_run_on_host() {
  local target="$1"
  shift
  local -a idargs=("$@")
  echo "== direct-host surgical-apply via $target =="
  # shellcheck disable=SC2029
  if [[ ${#idargs[@]} -gt 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=20 \
      -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
      "${idargs[@]}" "$target" \
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
  else
    ssh -o BatchMode=yes -o ConnectTimeout=20 \
      -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
      "$target" \
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
  fi
}

set +e
if _ssh_ok "$JUMP_SSH" "${JUMP_SSH_IDENTITY_ARGS[@]}"; then
  echo "OK jump reachable: $JUMP_SSH"
  _run_on_jump "${JUMP_SSH_IDENTITY_ARGS[@]}"
  RC=$?
else
  echo "WARN: jump unreachable ($JUMP_SSH); trying direct host fallback"
  RC=91
  if [[ "$ALLOW_DIRECT_HOST" == "1" ]]; then
    if _ssh_ok "$HOST_SSH" "${HOST_SSH_IDENTITY_ARGS[@]}"; then
      _run_on_host "$HOST_SSH" "${HOST_SSH_IDENTITY_ARGS[@]}"
      RC=$?
    elif _ssh_ok "$HOST_SSH_LAN" "${HOST_SSH_IDENTITY_ARGS[@]}"; then
      _run_on_host "$HOST_SSH_LAN" "${HOST_SSH_IDENTITY_ARGS[@]}"
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
