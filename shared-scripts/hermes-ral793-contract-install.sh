#!/usr/bin/env bash
# hermes-ral793-contract-install.sh — stage RAL-793 inventory contract on live .11
#
# Fail-closed install using hermes-agent-cos cos-local stage_ral793_inventory_contract.py.
# Updates dispatcher registry SHA pins in crontab/launchers when old pin appears exactly once.
# Does NOT dispatch by itself — use hermes-dispatcher-downstream.sh (auto DISPATCH-NOW default)
#   or post DISPATCH-NOW manually after verifying contract readback.
#
# Usage (credentialed Mac/cloud with SSH to .11):
#   bash shared-scripts/hermes-ral793-contract-install.sh
#   bash shared-scripts/hermes-ral793-contract-install.sh --dry-run
#   bash shared-scripts/hermes-ral793-contract-install.sh --post-linear
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
LINEAR_TICKET="${HERMES_RAL793_LINEAR_TICKET:-RAL-793}"
LINEAR_ISSUE_ID="${HERMES_RAL793_LINEAR_ISSUE_ID:-963472c8-cc84-426a-9ed6-79e08566353a}"
DRY_RUN=0
POST_LINEAR=0
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

_post_linear() {
  local body="$1"
  local key="${LINEAR_API_KEY:-${LINEAR_API_TOKEN:-}}"
  [[ -n "$key" ]] || return 0
  python3 - "$key" "$LINEAR_TICKET" "${LINEAR_ISSUE_ID:-}" "$body" <<'PY' 2>/dev/null || true
import json, sys, urllib.request
key, ticket, issue_id, body = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
iid = issue_id.strip()
if not iid:
    q1 = {"query": "query($q:String!){issueSearch(query:$q,first:1){nodes{id}}}", "variables": {"q": ticket}}
    req = urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q1).encode(),
        headers={"Content-Type": "application/json", "Authorization": key})
    with urllib.request.urlopen(req, timeout=12) as r:
        nodes = (json.load(r).get("data") or {}).get("issueSearch", {}).get("nodes") or []
    if not nodes:
        raise SystemExit(0)
    iid = nodes[0]["id"]
q2 = {"query": "mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){success}}",
      "variables": {"id": iid, "b": body}}
urllib.request.urlopen(urllib.request.Request("https://api.linear.app/graphql", data=json.dumps(q2).encode(),
    headers={"Content-Type": "application/json", "Authorization": key}), timeout=12).read()
PY
}

cleanup() { [[ -n "$TMP_HOST_KEY" && -f "$TMP_HOST_KEY" ]] && rm -f "$TMP_HOST_KEY"; }
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --post-linear) POST_LINEAR=1; shift ;;
    -h|--help) sed -n '1,22p' "$0"; exit 0 ;;
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
PREFLIGHT="$(_ssh_host "$HOST_TARGET" bash -s <<REMOTE
set -euo pipefail
REG="$REGISTRY"
if [[ ! -f "\$REG" ]]; then
  echo "FAIL registry missing: \$REG" >&2
  exit 12
fi
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); assert p.get("schema")=="cos.linear.execution_contract_registry.v1"; c=p.get("contracts") or {}; print("schema_ok", "RAL-793" in c)' "\$REG"
mkdir -p "$CANARY_ROOT/evidence" /opt/moltbot/data/cos-hermes/deploy-backups
[[ -f "$CANARY_ROOT/evidence/RAL-793-inventory.md" ]] || printf '%s\n' 'pending' > "$CANARY_ROOT/evidence/RAL-793-inventory.md"
printf 'pre_sha=%s\n' "\$(sha256sum "\$REG" | awk '{print \$1}')"
REMOTE
)"
echo "$PREFLIGHT"
if echo "$PREFLIGHT" | grep -q 'RAL-793.*True'; then
  echo "WARN: RAL-793 already in registry — skipping insert (readback only)" >&2
  READBACK="$(_ssh_host "$HOST_TARGET" bash -s <<REMOTE
set -euo pipefail
REG="$REGISTRY"
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); c=(p.get("contracts") or {}).get("RAL-793"); print("execution_mode", c.get("execution_mode")); print("allow_paths", c.get("implementation_allow_paths"))' "\$REG"
printf 'registry_sha=%s\n' "\$(sha256sum "\$REG" | awk '{print \$1}')"
REMOTE
)"
  echo "$READBACK"
  [[ "$POST_LINEAR" -eq 1 ]] && _post_linear "## RAL-793 contract readback @ $WHEN\n\nContract already present on live registry.\n\n\`\`\`\n$READBACK\n\`\`\`"
  echo "NEXT: DISPATCH-NOW RAL-793 if not yet run under pinned contract"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would install RAL-793 contract to $REGISTRY"
  exit 0
fi

echo "== upload stager + stage registry =="
scp "${HOST_SSH_IDENTITY_ARGS[@]}" "$STAGER" "${HOST_TARGET}:${REMOTE_STAGER}"

INSTALL_REPORT="$(_ssh_host "$HOST_TARGET" bash -s <<REMOTE
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
NEW_SHA="\$(sha256sum "\$REG" | awk '{print \$1}')"
printf 'backup=%s\n' "\$BACKUP"
printf 'registry_sha=%s\n' "\$NEW_SHA"
printf 'input_sha=%s\n' "\$INPUT_SHA"
REMOTE
)"
echo "$INSTALL_REPORT"

INPUT_SHA="$(echo "$INSTALL_REPORT" | awk -F= '/^input_sha=/{print $2}')"
NEW_SHA="$(echo "$INSTALL_REPORT" | awk -F= '/^registry_sha=/{print $2}')"
BACKUP_PATH="$(echo "$INSTALL_REPORT" | awk -F= '/^backup=/{print $2}')"

if [[ -n "$INPUT_SHA" && -n "$NEW_SHA" && "$INPUT_SHA" != "$NEW_SHA" ]]; then
  echo "== update registry SHA pins (crontab + launchers) =="
  PIN_REPORT="$(_ssh_host "$HOST_TARGET" bash -s -- "$INPUT_SHA" "$NEW_SHA" <<'REMOTE'
set -euo pipefail
OLD="$1"; NEW="$2"
updated=0
skipped=0

_update_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local count
  count="$(grep -c "$OLD" "$f" 2>/dev/null || echo 0)"
  [[ "$count" -eq 0 ]] && return 0
  if [[ "$count" -ne 1 ]]; then
    printf 'skip_file=%s reason=count_%s\n' "$f" "$count"
    skipped=$((skipped + 1))
    return 0
  fi
  cp "$f" "${f}.ral793-pin-backup.$(date -u +%Y%m%dT%H%M%SZ)"
  sed -i "s/${OLD}/${NEW}/g" "$f"
  case "$f" in
    *.sh) bash -n "$f" ;;
  esac
  printf 'pinned_file=%s\n' "$f"
  updated=$((updated + 1))
}

CRON="$(crontab -l 2>/dev/null || true)"
if echo "$CRON" | grep -q "$OLD"; then
  CCOUNT="$(echo "$CRON" | grep -c "$OLD" || echo 0)"
  if [[ "$CCOUNT" -eq 1 ]]; then
    printf '%s\n' "$CRON" | sed "s/${OLD}/${NEW}/g" | crontab -
    echo "pinned_crontab=1"
    updated=$((updated + 1))
  else
    echo "skip_crontab=count_${CCOUNT}"
    skipped=$((skipped + 1))
  fi
fi

while IFS= read -r f; do
  _update_file "$f"
done < <(find /opt/moltbot/shared-scripts /opt/moltbot/data/cos-hermes -maxdepth 4 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.json' \) 2>/dev/null | head -200)

printf 'pin_updated=%s\n' "$updated"
printf 'pin_skipped=%s\n' "$skipped"
REMOTE
)"
  echo "$PIN_REPORT"
fi

echo ""
echo "OK RAL-793 contract installed @ $WHEN"
echo "  backup=$BACKUP_PATH"
echo "  input_sha=$INPUT_SHA"
echo "  registry_sha=$NEW_SHA"
echo "NEXT: DISPATCH-NOW RAL-793 or hermes-now — expect inventory evidence on ticket"
echo "Do NOT treat prior WORK-PACKET-DONE as objective closure"

if [[ "$POST_LINEAR" -eq 1 ]]; then
  _post_linear "## RAL-793 contract installed @ $WHEN

host_ssh=\`$HOST_TARGET\`

| Field | Value |
|-------|-------|
| backup | \`$BACKUP_PATH\` |
| input_sha | \`$INPUT_SHA\` |
| registry_sha | \`$NEW_SHA\` |

Contract pinned. **Dispatch manually:** \`DISPATCH-NOW RAL-793\`

Expect \`evidence/RAL-793-inventory.md\` with EP04 map — not WORK-PACKET-DONE alone."
fi
