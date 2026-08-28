#!/usr/bin/env bash
# hermes-moltbot-cloud-tailscale-join-and-apply.sh — Cloud Cursor path to join Tailscale + land tip
#
# Paths:
#   A) TS_AUTHKEY set → join with authkey, then via-ssh surgical land
#   B) Already authenticated (interactive login approved) → skip join, via-ssh land
#   C) --wait-login → print AuthURL and wait until BackendState=Running, then land
#
# Mid-wait secret reload (cloud agents): if secrets are injected after start, they
# may appear in HERMES_CLOUD_SECRETS_ENV / TS_AUTHKEY file paths rather than the
# frozen process environment. Reloaded each wait tick.
# After Running + HERMES_AUTO_SURGICAL_LAND=0: wait for host SSH key before
# downstream (secrets often arrive after Tailscale approve). Jump ping is
# warn-only on this path (direct host SSH).
#
# Usage:
#   TS_AUTHKEY=tskey-auth-... bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh
#   bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh --already-up
#   bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh --wait-login
#   bash shared-scripts/hermes-moltbot-cloud-tailscale-join-and-apply.sh --dry-run
#
# Do not use Slack rockets. Do not git reset --hard /opt/moltbot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JUMP_HOST="${HERMES_JUMP_HOST:-100.92.147.61}"
JUMP_SSH="${HERMES_JUMP_SSH:-ilike4@${JUMP_HOST}}"
WAIT_SECS="${HERMES_TAILSCALE_WAIT_SECS:-90}"
LOGIN_WAIT_SECS="${HERMES_TAILSCALE_LOGIN_WAIT_SECS:-3600}"
SOCK="${HERMES_TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
SECRETS_ENV="${HERMES_CLOUD_SECRETS_ENV:-/tmp/hermes-cloud-apply/secrets.env}"
TS_KEY_FILE="${HERMES_TS_AUTHKEY_FILE:-/tmp/hermes-cloud-apply/ts-authkey}"
JUMP_KEY_FILE="${HERMES_JUMP_SSH_KEY_FILE:-/tmp/hermes-cloud-apply/jump-ssh-key}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-/tmp/hermes-cloud-apply/host-ssh-key}"
TS_UP_PIDFILE="${SCRIPT_DIR}/tailscale-up-wait.pid"
TS_UP_LOCK="${SCRIPT_DIR}/tailscale-up-wait.lock"
DRY_RUN=0
ALREADY_UP=0
WAIT_LOGIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --already-up) ALREADY_UP=1; shift ;;
    --wait-login) WAIT_LOGIN=1; shift ;;
    --wait-secs) WAIT_SECS="$2"; shift 2 ;;
    --ssh) JUMP_SSH="$2"; shift 2 ;;
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

echo "== cloud-tailscale-join-and-apply dry_run=$DRY_RUN already_up=$ALREADY_UP wait_login=$WAIT_LOGIN jump=$JUMP_SSH =="

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would install/join Tailscale (authkey or interactive), wait for $JUMP_HOST, then:"
  echo "  HERMES_JUMP_SSH=$JUMP_SSH bash $SCRIPT_DIR/hermes-moltbot-cloud-apply-install-via-ssh.sh"
  exit 0
fi

reload_cloud_secrets() {
  if [[ -f "$SECRETS_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$SECRETS_ENV"; set +a
  fi
  if [[ -z "${TS_AUTHKEY:-}" && -f "$TS_KEY_FILE" ]]; then
    TS_AUTHKEY="$(tr -d '\r\n' < "$TS_KEY_FILE")"
    export TS_AUTHKEY
  fi
  if [[ -z "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" && -f "$JUMP_KEY_FILE" ]]; then
    HERMES_JUMP_SSH_PRIVATE_KEY="$(cat "$JUMP_KEY_FILE")"
    export HERMES_JUMP_SSH_PRIVATE_KEY
  fi
  if [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" && -f "$HOST_KEY_FILE" ]]; then
    HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$HOST_KEY_FILE")"
    export HERMES_HOST_SSH_PRIVATE_KEY
  fi
  if [[ -z "${LINEAR_API_KEY:-}" && -f "${HERMES_LINEAR_API_KEY_FILE:-$SCRIPT_DIR/linear-api-key}" ]]; then
  