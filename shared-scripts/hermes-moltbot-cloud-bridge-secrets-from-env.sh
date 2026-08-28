#!/usr/bin/env bash
# Write agent-visible secrets into waiter secrets.env so mid-session inject works.
# Also mirrors LINEAR_API_KEY to $DIR/linear-api-key for waiters.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
ENV_OUT="$DIR/secrets.env"
SECRET_DIRS=( /tmp/cursor/cloud-agent-secrets /tmp/cursor-secrets "$HOME/.cursor/secrets" /opt/cursor/secrets )
mkdir -p "$DIR"
changed=0
: > "$ENV_OUT.tmp"
# Preserve non-secret refresh knob if present
if [[ -f "$ENV_OUT" ]] && grep -q '^HERMES_TAILSCALE_AUTHURL_REFRESH_SECS=' "$ENV_OUT" 2>/dev/null; then
  grep '^HERMES_TAILSCALE_AUTHURL_REFRESH_SECS=' "$ENV_OUT" >> "$ENV_OUT.tmp" || true
fi
if [[ -n "${TS_AUTHKEY:-}" ]]; then
  printf 'TS_AUTHKEY=%q\n' "$TS_AUTHKEY" >> "$ENV_OUT.tmp"
  changed=1
fi
if [[ -n "${HERMES_JUMP_SSH_PRIVATE_KEY:-}" ]]; then
  printf '%s\n' "$HERMES_JUMP_SSH_PRIVATE_KEY" > "$DIR/jump-ssh-key"
  chmod 600 "$DIR/jump-ssh-key"
  changed=1
fi
if [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
  printf '%s\n' "$HERMES_HOST_SSH_PRIVATE_KEY" > "$DIR/host-ssh-key"
  chmod 600 "$DIR/host-ssh-key"
  changed=1
fi
if [[ -n "${LINEAR_API_KEY:-}" ]]; then
  printf '%s\n' "$LINEAR_API_KEY" > "$DIR/linear-api-key"
  chmod 600 "$DIR/linear-api-key"
  printf 'LINEAR_API_KEY=%q\n' "$LINEAR_API_KEY" >> "$ENV_OUT.tmp"
  changed=1
elif [[ -n "${LINEAR_API_TOKEN:-}" ]]; then
  printf '%s\n' "$LINEAR_API_TOKEN" > "$DIR/linear-api-key"
  chmod 600 "$DIR/linear-api-key"
  printf 'LINEAR_API_KEY=%q\n' "$LINEAR_API_TOKEN" >> "$ENV_OUT.tmp"
  changed=1
fi
for f in "$DIR/ts-authkey" "${SECRET_DIRS[@]/%//TS_AUTHKEY}"; do
  if [[ -z "${TS_AUTHKEY:-}" && -f "$f" ]]; then
    TS_AUTHKEY="$(tr -d '\r\n' < "$f")"
    export TS_AUTHKEY
    printf 'TS_AUTHKEY=%q\n' "$TS_AUTHKEY" >> "$ENV_OUT.tmp"
    changed=1
  fi
done
for f in "$DIR/jump-ssh-key" "${SECRET_DIRS[@]/%//HERMES_JUMP_SSH_PRIVATE_KEY}"; do
  if [[ ! -s "$DIR/jump-ssh-key" && -f "$f" && "$f" != "$DIR/jump-ssh-key" ]]; then
    cp "$f" "$DIR/jump-ssh-key"
    chmod 600 "$DIR/jump-ssh-key"
    changed=1
  fi
done
for f in "$DIR/host-ssh-key" "${SECRET_DIRS[@]/%//HERMES_HOST_SSH_PRIVATE_KEY}"; do
  if [[ ! -s "$DIR/host-ssh-key" && -f "$f" && "$f" != "$DIR/host-ssh-key" ]]; then
    cp "$f" "$DIR/host-ssh-key"
    chmod 600 "$DIR/host-ssh-key"
    changed=1
  fi
done
for f in "$DIR/linear-api-key" "${SECRET_DIRS[@]/%//LINEAR_API_KEY}" "${SECRET_DIRS[@]/%//LINEAR_API_TOKEN}"; do
  if [[ ! -s "$DIR/linear-api-key" && -f "$f" && "$f" != "$DIR/linear-api-key" ]]; then
    tr -d '\r\n' < "$f" > "$DIR/linear-api-key"
    chmod 600 "$DIR/linear-api-key"
    changed=1
  fi
done
if [[ -s "$DIR/host-ssh-key" && -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
  HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$DIR/host-ssh-key")"
  export HERMES_HOST_SSH_PRIVATE_KEY
fi
if [[ -s "$DIR/linear-api-key" && -z "${LINEAR_API_KEY:-}" ]]; then
  LINEAR_API_KEY="$(tr -d '\r\n' < "$DIR/linear-api-key")"
  export LINEAR_API_KEY
  printf 'LINEAR_API_KEY=%q\n' "$LINEAR_API_KEY" >> "$ENV_OUT.tmp"
fi
if [[ -s "$ENV_OUT.tmp" ]]; then mv "$ENV_OUT.tmp" "$ENV_OUT"; else rm -f "$ENV_OUT.tmp"; fi
echo "bridge-secrets changed=$changed authkey=${TS_AUTHKEY:+set} jumpkey_file=$([[ -s $DIR/jump-ssh-key ]] && echo set || echo missing) hostkey_file=$([[ -s $DIR/host-ssh-key ]] && echo set || echo missing) linear_file=$([[ -s $DIR/linear-api-key ]] && echo set || echo missing)"
