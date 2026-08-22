#!/bin/bash
# HERMES-DIAGNOSE-THEN-LAND.command — SELF-CONTAINED one double-click
# Embeds diag + via-ssh vendor so land works even if raw/CDN fetch fails after download.
# Network fetch remains as fallback if embed extract fails.
set -euo pipefail
export HERMES_MAC_LAND_SOURCE="${HERMES_MAC_LAND_SOURCE:-public-diagnose-then-land-embedded}"
cd "${TMPDIR:-/tmp}"
echo "=== Hermes DIAGNOSE → LAND (self-contained) ==="
