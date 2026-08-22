#!/usr/bin/env bash
# Write agent-visible secrets into waiter secrets.env so mid-session inject works.
set -euo pipefail
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
ENV_OUT="$DIR/secrets.env"
mkdir -p "$DIR"
changed=0
: > "$ENV_OUT.tmp"
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
for f in "$DIR/ts-authkey" /tmp/cursor-secrets/TS_AUTHKEY "$HOME/.cursor/secrets/TS_AUTHKEY"; do
  if [[ -z "${TS_AUTHKEY:-}" && -f "$f" ]]; then
    TS_AUTHKEY="$(tr -d '\r\n' < "$f")"
    export TS_AUTHKEY
    printf 'TS_AUTHKEY=%q\n' "$TS_AUTHKEY" >> "$ENV_OUT.tmp"
    changed=1
  fi
done
for f in "$DIR/jump-ssh-key" /tmp/cursor-secrets/HERMES_JUMP_SSH_PRIVATE_KEY "$HOME/.cursor/secrets/HERMES_JUMP_SSH_PRIVATE_KEY"; do
  if [[ ! -s "$DIR/jump-ssh-key" && -f "$f" && "$f" != "$DIR/jump-ssh-key" ]]; then
    cp "$f" "$DIR/jump-ssh-key"
    chmod 600 "$DIR/jump-ssh-key"
    changed=1
  fi
done
for f in "$DIR/host-ssh-key" /tmp/cursor-secrets/HERMES_HOST_SSH_PRIVATE_KEY "$HOME/.cursor/secrets/HERMES_HOST_SSH_PRIVATE_KEY"; do
  if [[ ! -s "$DIR/host-ssh-key" && -f "$f" && "$f" != "$DIR/host-ssh-key" ]]; then
    cp "$f" "$DIR/host-ssh-key"
    chmod 600 "$DIR/host-ssh-key"
    changed=1
  fi
done
if [[ -s "$DIR/host-ssh-key" && -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]]; then
  HERMES_HOST_SSH_PRIVATE_KEY="$(cat "$DIR/host-ssh-key")"
  export HERMES_HOST_SSH_PRIVATE_KEY
fi
if [[ -s "$ENV_OUT.tmp" ]]; then mv "$ENV_OUT.tmp" "$ENV_OUT"; else rm -f "$ENV_OUT.tmp"; fi
echo "bridge-secrets changed=$changed authkey=${TS_AUTHKEY:+set} jumpkey_file=$([[ -s $DIR/jump-ssh-key ]] && echo set || echo missing) hostkey_file=$([[ -s $DIR/host-ssh-key ]] && echo set || echo missing)"
