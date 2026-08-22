#!/usr/bin/env bash
# Public Hermes Mac land — NO private moltbot fetch on Mac.
# Vendors via-ssh + Linear beacon from this public repo, then SSHes to grok-cos-1
# (jump clones private tip + installs apply watch). Needs: Tailscale + SSH BatchMode.
set -euo pipefail

SOURCE="${HERMES_MAC_LAND_SOURCE:-public-curl}"
VENDOR_DIR="${HERMES_MAC_LAND_VENDOR:-/tmp/hermes-mac-land-vendor-$$}"

_notify() {
  local title="$1" msg="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
  fi
  echo "== $title: $msg =="
}

_script_root() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" && "$src" != *bash && -f "$src" ]]; then
    cd "$(dirname "$src")" && pwd
  else
    echo ""
  fi
}

_fetch_vendor() {
  local root
  root="$(_script_root)"
  if [[ -n "$root" && -f "$root/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh" ]]; then
    VENDOR_DIR="$root"
    echo "OK co-located vendor $VENDOR_DIR"
    return 0
  fi
  rm -rf "$VENDOR_DIR"
  mkdir -p "$VENDOR_DIR/shared-scripts"
  local files=(
    shared-scripts/hermes-moltbot-land-beacon.sh
    shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh
  )
  local bases=(
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main"
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main"
  )
  local base f ok
  for base in "${bases[@]}"; do
    ok=1
    for f in "${files[@]}"; do
      echo "Fetching $base/$f"
      if ! curl -fsSL "$base/$f" -o "$VENDOR_DIR/$f"; then
        ok=0
        break
      fi
    done
    if [[ "$ok" -eq 1 ]] && grep -q 'grok-cos-1' "$VENDOR_DIR/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh"; then
      chmod +x "$VENDOR_DIR"/shared-scripts/*.sh
      echo "OK vendor from $base"
      return 0
    fi
  done
  return 1
}

_notify "Hermes UNBLOCK" "Public land (via-ssh only; no private Mac clone)…"

if ! _fetch_vendor; then
  _notify "Hermes UNBLOCK FAILED" "Could not fetch public via-ssh vendor scripts"
  echo "ERROR: vendor fetch failed" >&2
  exit 1
fi

BEACON="$VENDOR_DIR/shared-scripts/hermes-moltbot-land-beacon.sh"
VIA="$VENDOR_DIR/shared-scripts/hermes-moltbot-cloud-apply-install-via-ssh.sh"

if [[ -f "$BEACON" ]]; then
  bash "$BEACON" started --source "$SOURCE" || true
fi

if [[ ! -f "$VIA" ]]; then
  [[ -f "$BEACON" ]] && bash "$BEACON" failed --source "$SOURCE" --detail "missing via-ssh script" || true
  exit 1
fi

_notify "Hermes UNBLOCK" "SSH → grok-cos-1 surgical land…"
set +e
bash "$VIA"
RC=$?
set -e
if [[ "$RC" -ne 0 ]]; then
  [[ -f "$BEACON" ]] && bash "$BEACON" failed --source "$SOURCE" --detail "via-ssh exited $RC" || true
  _notify "Hermes UNBLOCK FAILED" "via-ssh exited $RC — Tailscale + SSH BatchMode to grok-cos-1?"
  exit "$RC"
fi

_notify "Hermes UNBLOCK OK" "Expect Linear Host surgical-apply OK"
echo "OK hermes-mac-land finished (via-ssh; no private moltbot on Mac)"
exit 0
