#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — curl|bash / Mac ONE-SHOT safe entrypoint
#
# Assembles part-a/b/c then execs. If co-located parts are missing (piped bash,
# or ONE-SHOT/STALL download into /tmp), fetches parts from tip raw URLs.
# If tip CDN for HERMES_DOWNSTREAM_REF fails, falls back to known-good
# HERMES_DOWNSTREAM_FALLBACK_REF (default ff0ccac = tip #156 DONE-post curl/gh + tip #150/#151 inventory integrity).
# Tip #152: do NOT fall back to pre-#150/#151 SHAs (SEED false-pass / deferred=DONE).
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

if [[ "$_have_local_parts" != "1" ]]; then
  echo "OK downstream entrypoint: fetching part-a/b/c from ${REPO}@${REF}"
  if ! _fetch_parts "$REF"; then
    if [[ "$REF" != "$FALLBACK" ]]; then
      echo "WARN tip fetch failed for ${REF}; falling back to ${FALLBACK}"
      if ! _fetch_parts "$FALLBACK"; then
        echo "FAIL could not fetch part-a/b/c from ${REF} or fallback ${FALLBACK}" >&2
        exit 1
      fi
      REF="$FALLBACK"
    else
      echo "FAIL could not fetch part-a/b/c from ${REF}" >&2
      exit 1
    fi
  fi
fi

ASM="$WORK/.hermes-dispatcher-downstream.assembled.sh"
cat "$WORK/hermes-dispatcher-part-a.sh" \
    "$WORK/hermes-dispatcher-part-b.sh" \
    "$WORK/hermes-dispatcher-part-c.sh" > "$ASM"
chmod +x "$ASM"
exec bash "$ASM" "$@"
