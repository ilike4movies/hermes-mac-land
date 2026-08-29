#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — curl|bash / Mac ONE-SHOT safe entrypoint
#
# Assembles part-a/b/c then execs. If co-located parts are missing (piped bash,
# or ONE-SHOT/STALL download into /tmp), fetches parts from tip raw URLs.
# If tip CDN for HERMES_DOWNSTREAM_REF fails, falls back to known-good
# HERMES_DOWNSTREAM_FALLBACK_REF (default ff0ccac = tip #156 DONE-post curl/gh + tip #150/#151 inventory integrity).
# Tip #152: do NOT fall back to pre-#150/#151 SHAs (SEED false-pass / deferred=DONE).
# Tip #158/#159: reject parts missing tip #156 DONE-post + #150/#151 inventory + #159 fail-closed status
# (stale CDN/local co-located parts that still fetch OK but silent-fail GitHub status).
# Do NOT replace this with a local-only cat of parts — that breaks Mac ONE-SHOT.
set -euo pipefail

REPO="${HERMES_DOWNSTREAM_REPO:-ilike4movies/hermes-mac-land}"
REF="${HERMES_DOWNSTREAM_REF:-main}"
FALLBACK="${HERMES_DOWNSTREAM_FALLBACK_REF:-ff0ccac}"

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != *"/dev/fd/"* ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

WORK="${HERMES_DOWNSTREAM_WORK:-/tmp/hermes-downstream-assembled-$$}"
mkdir -p "$WORK"

_have_local_parts=1
for p in hermes-dispatcher-part-a.sh hermes-dispatcher-part-b.sh hermes-dispatcher-part-c.sh; do
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$p" ]]; then
    cp "$SCRIPT_DIR/$p" "$WORK/$p"
  else
    _have_local_parts=0
  fi
done

_fetch_parts() {
  local ref="$1"
  local base="https://raw.githubusercontent.com/${REPO}/${ref}/shared-scripts"
  local p
  for p in hermes-dispatcher-part-a.sh hermes-dispatcher-part-b.sh hermes-dispatcher-part-c.sh; do
    curl -fsSL "$base/$p" -o "$WORK/$p" || return 1
  done
  return 0
}

# Tip #158: tip #156 DONE-post + tip #150/#151 inventory integrity must be present.
_parts_integrity_ok() {
  local d="$1"
  grep -q 'HERMES_GH_BEACON_TIMEOUT_SECS' "$d/hermes-dispatcher-part-a.sh" 2>/dev/null \
    && grep -q 'HERMES_STATUS_GITHUB_TOKEN' "$d/hermes-dispatcher-part-a.sh" 2>/dev/null \
    && grep -q 'FAIL GitHub status post failed' "$d/hermes-dispatcher-part-a.sh" 2>/dev/null \
    && grep -q '_inventory_evidence_ok' "$d/hermes-dispatcher-part-b.sh" 2>/dev/null \
    && grep -q 'inventory deferred' "$d/hermes-dispatcher-part-c.sh" 2>/dev/null \
    && grep -q 'Downstream DONE beacon did not post' "$d/hermes-dispatcher-part-c.sh" 2>/dev/null
}

_ensure_parts() {
  if [[ "$_have_local_parts" == "1" ]] && _parts_integrity_ok "$WORK"; then
    echo "OK downstream entrypoint: using co-located tip#156+ parts"
    return 0
  fi
  if [[ "$_have_local_parts" == "1" ]]; then
    echo "WARN co-located parts fail tip#158 integrity (pre-#156/#150/#151); fetching tip"
    _have_local_parts=0
  fi
  echo "OK downstream entrypoint: fetching part-a/b/c from ${REPO}@${REF}"
  if _fetch_parts "$REF" && _parts_integrity_ok "$WORK"; then
    return 0
  fi
  if [[ "$REF" != "$FALLBACK" ]]; then
    echo "WARN tip ${REF} missing/incomplete tip#158 markers; falling back to ${FALLBACK}"
    if _fetch_parts "$FALLBACK" && _parts_integrity_ok "$WORK"; then
      REF="$FALLBACK"
      return 0
    fi
    echo "FAIL could not fetch tip#158-ok part-a/b/c from ${REF} or fallback ${FALLBACK}" >&2
    exit 1
  fi
  echo "FAIL could not fetch tip#158-ok part-a/b/c from ${REF}" >&2
  exit 1
}

_ensure_parts

ASM="$WORK/.hermes-dispatcher-downstream.assembled.sh"
cat "$WORK/hermes-dispatcher-part-a.sh" \
    "$WORK/hermes-dispatcher-part-b.sh" \
    "$WORK/hermes-dispatcher-part-c.sh" > "$ASM"
chmod +x "$ASM"
exec bash "$ASM" "$@"
