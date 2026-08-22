#!/usr/bin/env bash
# Public Hermes Mac land — NO private moltbot fetch on Mac.
# Vendors via-ssh + Linear beacon from this public repo, then SSHes to .11 directly
# by default (HERMES_PREFER_DIRECT_HOST=1). Jump grok-cos-1 is optional fallback.
# Needs: Tailscale and/or home LAN + SSH BatchMode to .11.
# Default pin is main; override with HERMES_MAC_LAND_PIN for a frozen SHA.
set -euo pipefail

SOURCE="${HERMES_MAC_LAND_SOURCE:-public-curl}"
VENDOR_DIR="${HERMES_MAC_LAND_VENDOR:-/tmp/hermes-mac-land-vendor-$$}"
PIN="${HERMES_MAC_LAND_PIN:-main}"
# Mac Hermes at home reaches .11 directly; jump install often fails (private clone on grok-cos-1).
export HERMES_PREFER_DIRECT_HOST="${HERMES_PREFER_DIRECT_HOST:-1}"

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
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/${PIN}"
    "https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main"
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@${PIN}"
    "https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main"
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
      if head -1 "$VENDOR_DIR/$f" | grep -q '^IyE'; then
        echo "WARN: base64 stub at $base/$f"
        ok=0
        break
      fi
      if grep -q '^PLACEHOLDER$' "$VENDOR_DIR/$f" 2>/dev/null; then
        echo "WARN: PLACEHOLDER at $base/$f"
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

_notify "Hermes UNBLOCK" "Public land (direct .11 default; via-ssh vendor)…"

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

if [[ "${HERMES_PREFER_DIRECT_HOST}" == "1" ]]; then
  _notify "Hermes UNBLOCK" "SSH → .11 direct surgical land…"
else
  _notify "Hermes UNBLOCK" "SSH → grok-cos-1 surgical land (jump first)…"
fi
set +e
bash "$VIA"
RC=$?
set -e
if [[ "$RC" -ne 0 ]]; then
  [[ -f "$BEACON" ]] && bash "$BEACON" failed --source "$SOURCE" --detail "land exited $RC prefer_direct=${HERMES_PREFER_DIRECT_HOST}" || true
  _notify "Hermes UNBLOCK FAILED" "land exited $RC — SSH BatchMode to .11 (192.168.1.11 or 100.105.194.96)?"
  echo "Retry: curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash" >&2
  echo "Probe: ssh -o BatchMode=yes -o ConnectTimeout=8 ilike4@192.168.1.11 hostname" >&2
  exit "$RC"
fi

_notify "Hermes UNBLOCK OK" "Expect Linear Host surgical-apply OK"
echo "OK hermes-mac-land finished (expect OK INTERRUPT_LABEL hermes-now in output above)"
exit 0
