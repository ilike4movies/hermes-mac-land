#!/usr/bin/env bash
# hermes-stage-a-source-preflight.sh — read-only cos-local source gate (no SSH)
#
# Validates hermes-agent-cos cos-local @ pinned SHA before live Stage A on .11.
# Runs execution-engine source validators + WAL finalizer pin check.
#
# Usage:
#   bash shared-scripts/hermes-stage-a-source-preflight.sh
#   bash shared-scripts/hermes-stage-a-source-preflight.sh --json
#
# No live mutation. Exit 0 = source ready for bounded Stage A activation.
set -euo pipefail

COS_LOCAL_SHA="${HERMES_COS_LOCAL_SHA:-5bcb257e}"
COS_OWNER_REPO="${HERMES_COS_OWNER_REPO:-ilike4movies/hermes-agent-cos}"
COS_BRANCH="${HERMES_COS_BRANCH:-cos-local}"
JSON_OUT=0
EXTRACT_DIR=""

cleanup() {
  [[ -n "$EXTRACT_DIR" && -d "$EXTRACT_DIR" ]] && rm -rf "$EXTRACT_DIR"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    -h|--help)
      sed -n '1,18p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "FAIL: gh required for cos-local source preflight" >&2
  exit 11
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required for cos-local source preflight" >&2
  exit 12
fi

tip="$(gh api "repos/${COS_OWNER_REPO}/commits/${COS_BRANCH}" --jq .sha 2>/dev/null || echo unknown)"
if ! printf '%s' "$tip" | grep -qi "^${COS_LOCAL_SHA}"; then
  echo "FAIL cos-local tip mismatch: need ${COS_LOCAL_SHA}* got ${tip}" >&2
  exit 13
fi

EXTRACT_DIR="/tmp/hermes-cos-source-preflight-$$"
mkdir -p "$EXTRACT_DIR"
if ! gh api "repos/${COS_OWNER_REPO}/tarball/${COS_BRANCH}" | tar -xz -C "$EXTRACT_DIR" 2>/dev/null; then
  echo "FAIL could not fetch ${COS_OWNER_REPO}@${COS_BRANCH} tarball" >&2
  exit 14
fi

SRC_ROOT="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)"
if [[ -z "$SRC_ROOT" || ! -d "$SRC_ROOT" ]]; then
  echo "FAIL empty cos-local tarball extract" >&2
  exit 15
fi

FAILS=()
PASS=()

guard_init="${SRC_ROOT}/ops/ral733-budget-guard/__init__.py"
if [[ ! -f "$guard_init" ]]; then
  FAILS+=("missing ops/ral733-budget-guard/__init__.py")
elif ! grep -q 'finalize_worker_session_usage' "$guard_init"; then
  FAILS+=("WAL finalizer finalize_worker_session_usage missing")
elif ! grep -q 'reportback_verified' "$guard_init"; then
  FAILS+=("reportback_verified path missing in WAL finalizer")
else
  PASS+=("WAL finalizer present @ cos-local@${COS_LOCAL_SHA}")
fi

for script in \
  ops/rjs-execution-engine-live-bundle/preflight_source.py \
  ops/rjs-execution-engine-live-bundle/deployment_packet_preflight.py
do
  if [[ ! -f "${SRC_ROOT}/${script}" ]]; then
    FAILS+=("missing ${script}")
    continue
  fi
  if out="$(python3 "${SRC_ROOT}/${script}" --source-root "$SRC_ROOT" 2>&1)"; then
    if printf '%s' "$out" | grep -q 'SOURCE_READY_LIVE_NOT_AUTHORIZED'; then
      PASS+=("${script} OK")
    else
      FAILS+=("${script} unexpected output")
    fi
  else
    FAILS+=("${script} failed: $(printf '%s' "$out" | head -1)")
  fi
done

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$JSON_OUT" -eq 1 ]]; then
  python3 - <<PY
import json
print(json.dumps({
    "when": "${WHEN}",
    "cos_local_sha": "${COS_LOCAL_SHA}",
    "cos_branch": "${COS_BRANCH}",
    "pass": $(printf '%s\n' "${PASS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
    "fail": $(printf '%s\n' "${FAILS[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))'),
    "ok": $( [[ ${#FAILS[@]} -eq 0 ]] && echo True || echo False ),
}, indent=2))
PY
else
  echo "== Stage A source preflight (read-only, no SSH) @ $WHEN =="
  echo "cos_local_pin=${COS_LOCAL_SHA} (${COS_OWNER_REPO}@${COS_BRANCH})"
  echo
  for item in "${PASS[@]}"; do echo "PASS: $item"; done
  for item in "${FAILS[@]}"; do echo "FAIL: $item"; done
  echo
  if [[ ${#FAILS[@]} -eq 0 ]]; then
    echo "RESULT: PASS — source ready; run hermes-stage-a-preflight.sh on credentialed .11 agent"
    echo "Stage A only token: APPROVE-RJS-LIVE-BUNDLE-1"
    echo "Full bundle token: APPROVE-RJS-EXECUTION-ENGINE-LIVE-1"
  else
    echo "RESULT: BLOCKED — fix source failures before live Stage A"
  fi
fi

if [[ ${#FAILS[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
