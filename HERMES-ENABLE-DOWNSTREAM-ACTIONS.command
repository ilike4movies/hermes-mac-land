#!/bin/bash
# Tip #182: HERMES-ENABLE-DOWNSTREAM-ACTIONS.command
# Wrapper: fetch tip181 ENABLE body and bump tip banner to #182.
set -euo pipefail
REPO="${HERMES_MAC_LAND_REPO:-ilike4movies/hermes-mac-land}"
_TMP="$(mktemp)"
curl -fsSL --max-time 15 \
  "https://raw.githubusercontent.com/${REPO}/2c5f078fec27dfb9f97badb42171b763b196e72a/HERMES-ENABLE-DOWNSTREAM-ACTIONS.command" \
  -o "$_TMP"
python3 - "$_TMP" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8", errors="replace").read()
t2 = re.sub(r"tip through #181\b", "tip through #182", t, count=1)
if "tip through #182" not in t2:
    t2 = t.replace("tip through #181", "tip through #182", 1)
open(p, "w", encoding="utf-8").write(t2)
PY
chmod +x "$_TMP"
exec bash "$_TMP" "$@"
