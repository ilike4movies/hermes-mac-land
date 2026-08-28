#!/usr/bin/env bash
# hermes-dispatcher-downstream.sh — curl|bash / Mac ONE-SHOT safe entrypoint
#
# Assembles part-a/b/c then execs. If co-located parts are missing (piped bash,
# or ONE-SHOT/STALL download into /tmp), fetches parts from tip raw URLs.
# Do NOT replace this with a local-only cat of parts — that breaks Mac ONE-SHOT.
set -euo pipefail

REPO="${HERMES_DOWNSTREAM_REPO:-ilike4movies/hermes-mac-land}"
REF="${HERMES_DOWNSTREAM_REF:-main}"
BASE="https://raw.githubusercontent.com/${REPO}/${REF}/shared-scripts"

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

if [[ "$_have_local_parts" != "1" ]]; then
  echo "OK downstream entrypoint: fetching part-a/b/c from ${REPO}@${REF}"
  for p in hermes-dispatcher-part-a.sh hermes-dispatcher-part-b.sh hermes-dispatcher-part-c.sh; do
    curl -fsSL "$BASE/$p" -o "$WORK/$p"
  done
fi

ASM="$WORK/.hermes-dispatcher-downstream.assembled.sh"
cat "$WORK/hermes-dispatcher-part-a.sh" \
    "$WORK/hermes-dispatcher-part-b.sh" \
    "$WORK/hermes-dispatcher-part-c.sh" > "$ASM"
chmod +x "$ASM"
exec bash "$ASM" "$@"
