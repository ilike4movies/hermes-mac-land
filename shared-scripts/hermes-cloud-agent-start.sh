#!/usr/bin/env bash
# Cursor Cloud Agent start hook — bootstrap waiter + optional immediate surgical land.
# Requires Runtime Secrets at boot: TS_AUTHKEY, HERMES_HOST_SSH_PRIVATE_KEY.
# Set HERMES_AUTO_SURGICAL_LAND=0 to disable immediate land (waiter still runs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${HERMES_CLOUD_APPLY_DIR:-/tmp/hermes-cloud-apply}"
mkdir -p "$DIR"
export HERMES_CLOUD_APPLY_DIR="$DIR"
LOG="$DIR/auto-land.log"

_preflight() {
  if [[ ! -f "$ROOT/OPERATOR-UNBLOCK.md" ]]; then
    echo "ERROR: Hermes cloud land requires repo ilike4movies/hermes-mac-land (OPERATOR-UNBLOCK.md missing)." >&2
    echo "Do not use Ooterverse-Saturns-Quest for Hermes deploy. See OPERATOR-UNBLOCK.md on hermes-mac-land main." >&2
    return 1
  fi
  if [[ "${COMPOSER_REPO_URL:-}" == *ooterverse* ]] || [[ "${COMPOSER_REPO_URL:-}" == *Ooterverse* ]]; then
    echo "ERROR: wrong cloud agent repo (${COMPOSER_REPO_URL:-unknown})." >&2
    echo "Start a NEW agent on ilike4movies/hermes-mac-land with env LEGACY Hermes .11." >&2
    echo "Ooterverse override/mobile agents cannot receive Hermes secrets at boot." >&2
    return 1
  fi
  return 0
}

_missing_secrets() {
  local missing=()
  [[ -z "${TS_AUTHKEY:-}" ]] && missing+=(TS_AUTHKEY)
  [[ -z "${HERMES_HOST_SSH_PRIVATE_KEY:-}" ]] && missing+=(HERMES_HOST_SSH_PRIVATE_KEY)
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing Runtime Secrets at boot: ${missing[*]}" >&2
    echo "Web UI → hermes-mac-land → env LEGACY Hermes .11 — do not use for Ooterverse." >&2
    echo "Mobile/Ooterverse override agents cannot receive secrets mid-session." >&2
    echo "See $ROOT/OPERATOR-UNBLOCK.md" >&2
    return 0
  fi
  return 1
}

_preflight || exit 0

bash "$ROOT/shared-scripts/hermes-cloud-bootstrap-waiter.sh" || true

if [[ -x "$DIR/bridge-secrets-from-env.sh" ]]; then
  bash "$DIR/bridge-secrets-from-env.sh" || true
fi

if [[ "${HERMES_AUTO_SURGICAL_LAND:-1}" != "1" ]]; then
  echo "INFO: auto-land disabled (HERMES_AUTO_SURGICAL_LAND=0)"
  exit 0
fi

if _missing_secrets; then
  echo "INFO: auto-land skipped — attach secrets at boot (see OPERATOR-UNBLOCK.md path A)"
  exit 0
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "WARN: tailscale not installed — waiter will retry; land deferred" >&2
  exit 0
fi

ts_state="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("BackendState","unknown"))' 2>/dev/null || echo unknown)"
if [[ "$ts_state" != "Running" ]]; then
  echo "WARN: Tailscale BackendState=$ts_state (need Running) — waiter will retry; land deferred" >&2
  exit 0
fi

echo "OK secrets at boot + Tailscale Running — attempting surgical land (jump-first)"
# Jump-first installs cloud-apply watch on grok-cos-1; direct fallback uses moltbot #79 local watch.
# Override with HERMES_PREFER_DIRECT_HOST=1 to skip jump.
export HERMES_PREFER_DIRECT_HOST="${HERMES_PREFER_DIRECT_HOST:-0}"
export HERMES_UPLOAD_TIP_FROM_CALLER=1
export HERMES_POST_APPLY_CANARY="${HERMES_POST_APPLY_CANARY:-RAL-820}"
if bash "$ROOT/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh" >>"$LOG" 2>&1; then
  echo "OK surgical land — see $LOG"
  if [[ "${HERMES_AUTO_STAGE_A_PREFLIGHT:-1}" == "1" ]]; then
    PREFLIGHT="$DIR/hermes-stage-a-preflight.sh"
    [[ -x "$PREFLIGHT" ]] || PREFLIGHT="$ROOT/shared-scripts/hermes-stage-a-preflight.sh"
    if [[ -x "$PREFLIGHT" ]]; then
      SRC_PREFLIGHT="$DIR/hermes-stage-a-source-preflight.sh"
      [[ -x "$SRC_PREFLIGHT" ]] || SRC_PREFLIGHT="$ROOT/shared-scripts/hermes-stage-a-source-preflight.sh"
      if [[ -x "$SRC_PREFLIGHT" ]] && [[ "${HERMES_AUTO_STAGE_A_SOURCE_PREFLIGHT:-1}" == "1" ]]; then
        echo "OK running read-only Stage A source preflight (cos-local@5bcb257e)"
        bash "$SRC_PREFLIGHT" >>"$LOG" 2>&1 || echo "WARN: Stage A source preflight blocked — see $LOG" >&2
      fi
      echo "OK running read-only Stage A live preflight (cos-local@5bcb257e)"
      bash "$PREFLIGHT" >>"$LOG" 2>&1 || echo "WARN: Stage A preflight blocked — see $LOG" >&2
    else
      echo "WARN: hermes-stage-a-preflight.sh missing — run bootstrap waiter first" >&2
    fi
  fi
else
  echo "WARN: auto-land failed — see $LOG" >&2
fi
exit 0
