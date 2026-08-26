#!/usr/bin/env bash
# hermes-ral793-contract-install.sh — stage RAL-793 inventory contract on live .11
#
# Fail-closed install using hermes-agent-cos cos-local stage_ral793_inventory_contract.py.
# Does NOT dispatch — operator must verify readback then DISPATCH-NOW manually.
#
# Usage (credentialed Mac/cloud with SSH to .11):
#   bash shared-scripts/hermes-ral793-contract-install.sh
#   bash shared-scripts/hermes-ral793-contract-install.sh --dry-run
#
# See docs/RAL-793-CONTRACT-STAGING.md
set -euo pipefail

HOST_SSH="${HERMES_MOLTBOT_SSH:-ilike4@100.105.194.96}"
HOST_SSH_LAN="${HERMES_MOLTBOT_SSH_LAN:-ilike4@192.168.1.11}"
KEY_DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
HOST_KEY_FILE="${HERMES_HOST_SSH_KEY_FILE:-$KEY_DIR/host-ssh-key}"
REGISTRY="${HERMES_EXECUTION_REGISTRY:-/opt/moltbot/data/cos-hermes/execution-contract-registry.json}"
CANARY_ROOT="/opt/moltbot/data/cos-hermes/canaries/ral793-inventory"
COS_REPO="${HERMES_COS_OWNER_REPO:-ilike4movies/hermes-agent-cos}"
COS_BRANCH="${HERMES_COS_BRANCH:-cos-local}"
DRY_RUN=0
TMP_HOST_KEY=""
HOST_SSH_IDENTITY_ARGS=()

_load_hermes_ssh_env() {
  local f key val
  for f in "${HOME}/.hermes/.env" /opt/moltbot/config/secrets.env "${HOME}/.openclaw/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ''|\#*) continue ;;
        HERMES_HOST_SSH_PRIVATE_KEY=*|LINEAR_API_KEY=*|LINEAR_API_TOKEN=*)
          key="${line%%=*}"
          val="${line#*=}"
          val="${val%\"}"; val="${val#\"}"
          val="${val%\'}"; val="${val#\'}"
          [[ -z "${!key:-}" ]] && export "$key=$val"
          ;;
      esac
    done < "$f"
  done
}

_write_keyfile() {
  local f
  f="$(mktemp /tmp/hermes-ral793-ssh.XXXXXX)"
  printf '%s\n' "$1" > "$f"
  chmod 600 "$f"
  echo "$f"
}

_load_host_pem() {
  [[ -n "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && printf '%s' "$HERMES_HOST_SSH_PRIVATE_KEY" && return 0
  [[ -s "$HOST_KEY_FILE" ]] && cat "$HOST_KEY_FILE" && return 0
  return 1
}

cleanup() { [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"; }
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '1,18p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

_load_hermes_ssh_env || true
if _host_pem="$(_load_host_pem 2>/dev/null)"; then
  TMP_HOST_KEY="$(_write_keyfile "$_host_pem")"
  HOST_SSH_IDENTITY_ARGS=(-i "$TMP_HOST_KEY" -o IdentitiesOnly=yes)
fi

_ssh_host() {
  local target="$1"; shift
  if [[ ${#HOST_SSH_IDENTITY_ARGS[@]} -gt 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new \
      "${HOST_SSH_IDENTITY_ARGS[@]}" "$target" "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "$target" "$@"
  fi
}

_pick_host() {
  _ssh_host "$HOST_SSH" 'echo OK' >/dev/null 2>&1 && { echo "$HOST_SSH"; return 0; }
  _ssh_host "$HOST_SSH_LAN" 'echo OK' >/dev/null 2>&1 && { echo "$HOST_SSH_LAN"; return 0; }
  return 1
}

HOST_TARGET=""
HOST_TARGET="$(_pick_host)" || { echo "FAIL SSH to .11" >&2; exit 10; }

WORKDIR="$(mktemp -d /tmp/hermes-ral793-install.XXXXXX)"
trap 'rm -rf "$WORKDIR"; cleanup' EXIT

echo "== fetch cos-local stager =="
if command -v gh >/dev/null 2>&1; then
  gh api "repos/${COS_REPO}/tarball/${COS_BRANCH}" | tar -xz -C "$WORKDIR"
else
  curl -fsSL "https://api.github.com/repos/${COS_REPO}/tarball/${COS_BRANCH}" | tar -xz -C "$WORKDIR"
fi
INNER="$(find "$WORKDIR" -mindepth 1 -maxdepth 1 -type d | head -1)"
STAGER="$INNER/ops/ral798-control-loop/stage_ral793_inventory_contract.py"
[[ -f "$STAGER" ]] || { echo "FAIL missing stager in cos-local tarball" >&2; exit 11; }

REMOTE_STAGER="/tmp/stage_ral793_inventory_contract.py"
REMOTE_STAGE_OUT="/tmp/ral793-registry-staged.json"
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BACKUP_SUFFIX="$(date -u +%Y%m%dT%H%M%SZ)"

echo "== remote preflight host=$HOST_TARGET =="
_ssh_host "$HOST_TARGET" bash -s <<REMOTE
set -euo pipefail
REG="$REGISTRY"
if [[ ! -f "\$REG" ]]; then
  echo "FAIL registry missing: \$REG" >&2
  exit 12
fi
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); assert p.get("schema")=="cos.linear.execution_contract_registry.v1"; c=p.get("contracts") or {}; print("schema_ok", "RAL-793" in c)' "\$REG"
mkdir -p "$CANARY_ROOT/evidence" /opt/moltbot/data/cos-hermes/deploy-backups
[[ -f "$CANARY_ROOT/evidence/RAL-793-inventory.md" ]] || printf '%s\n' 'pending' > "$CANARY_ROOT/evidence/RAL-793-inventory.md"
REMOTE

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would install RAL-793 contract to $REGISTRY"
  exit 0
fi

echo "== upload stager + stage registry =="
scp "${HOST_SSH_IDENTITY_ARGS[@]}" "$STAGER" "${HOST_TARGET}:${REMOTE_STAGER}"

_ssh_host "$HOST_TARGET" bash -s <<REMOTE
set -euo pipefail
REG="$REGISTRY"
BACKUP="/opt/moltbot/data/cos-hermes/deploy-backups/execution-contract-registry.${BACKUP_SUFFIX}.json"
cp "\$REG" "\$BACKUP"
chmod 600 "\$BACKUP"
INPUT_SHA="\$(sha256sum "\$REG" | awk '{print \$1}')"
python3 "$REMOTE_STAGER" \\
  --registry-input "\$REG" \\
  --registry-output "$REMOTE_STAGE_OUT" \\
  --expected-input-sha256 "\$INPUT_SHA"
install -m 0644 "$REMOTE_STAGE_OUT" "\$REG"
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); c=(p.get("contracts") or {}).get("RAL-793"); assert c, "RAL-793 missing"; assert c.get("execution_mode")=="implement"' "\$REG"
printf 'backup=%s\n' "\$BACKUP"
printf 'registry_sha=%s\n' "\$(sha256sum "\$REG" | awk '{print \$1}')"
printf 'input_sha=%s\n' "\$INPUT_SHA"
REMOTE

echo ""
echo "OK RAL-793 contract installed @ $WHEN"
echo "NEXT: update orchestrator registry hash pin if embedded (see docs/RAL-793-CONTRACT-STAGING.md)"
echo "Then DISPATCH-NOW RAL-793 or hermes-now — expect inventory evidence on ticket"
echo "Do NOT treat prior WORK-PACKET-DONE as objective closure"
