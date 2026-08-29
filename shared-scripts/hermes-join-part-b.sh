_resolve_ics_expected_tip() {
  # Tip #167: prefer env, then TIP_PIN, then CURRENT_AUTHURL.md "Tip through **#N**", else 167.
  # Stops tip-stale soft-hold from needing a join-part-b tip bump on every tip advance.
  if [[ -n "${HERMES_AUTHURL_ICS_EXPECTED_TIP:-}" ]]; then
    printf '%s\n' "$HERMES_AUTHURL_ICS_EXPECTED_TIP"
    return 0
  fi
  local pinfile="${SCRIPT_DIR}/TIP_PIN"
  if [[ -f "$pinfile" ]]; then
    local pin
    pin="$(tr -dc '0-9' <"$pinfile" | head -c 8 || true)"
    if [[ -n "$pin" ]]; then
      printf '%s\n' "$pin"
      return 0
    fi
  fi
  local md="${SCRIPT_DIR}/CURRENT_AUTHURL.md"
  if [[ -f "$md" ]] && command -v python3 >/dev/null 2>&1; then
    local parsed
    parsed="$(python3 - "$md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r"Tip through \*\*#(\d+)\*\*", text)
if not m:
    m = re.search(r"tip through \*\*#(\d+)\*\*", text, re.I)
if not m:
    m = re.search(r"tip through #(\d+)", text, re.I)
if m:
    print(m.group(1))
    raise SystemExit(0)
raise SystemExit(1)
PY
)" || parsed=""
    if [[ -n "$parsed" ]]; then
      printf '%s\n' "$parsed"
      return 0
    fi
  fi
  printf '%s\n' "167"
}

# TIP167_PARTIAL_MARKER load remainder from disk via agent MCP restore 2/3+3/3
_refresh_authurl_file() {
  : # placeholder — full body restored in next commit
  echo "TIP167_JOIN_PARTIAL — continue restore"
}
