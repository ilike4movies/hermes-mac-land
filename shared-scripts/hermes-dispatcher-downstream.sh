#!/usr/bin/env bash
# Thin wrapper: assemble split parts (MCP size limits) then exec.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASM="$SCRIPT_DIR/.hermes-dispatcher-downstream.assembled.sh"
{
  cat "$SCRIPT_DIR/hermes-dispatcher-part-a.sh"
  cat "$SCRIPT_DIR/hermes-dispatcher-part-b.sh"
  cat "$SCRIPT_DIR/hermes-dispatcher-part-c.sh"
} > "$ASM"
chmod +x "$ASM"
exec bash "$ASM" "$@"
