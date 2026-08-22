# Hermes Mac land (public bootstrap)

## Fastest — one double-click (diagnose + land)

1. Open: https://github.com/ilike4movies/hermes-mac-land
2. Download a **fresh** `HERMES-DIAGNOSE-THEN-LAND.command`
3. Double-click on **Mac Hermes** (Tailscale up)

Runs diagnostic first (Desktop + clipboard + Linear/GitHub), then via-ssh land.
Diag also opens **RAL-800** + [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) in the browser so you can paste Desktop diag if remote post fails.

Land path: jump `grok-cos-1` first; if jump is down, tries `.11` directly (Tailscale `100.105.194.96` or LAN `192.168.1.11`).

Gatekeeper:
`xattr -d com.apple.quarantine ~/Downloads/HERMES-DIAGNOSE-THEN-LAND.command && open ~/Downloads/HERMES-DIAGNOSE-THEN-LAND.command`

## Or land only

1. Download a **fresh** `HERMES-UNBLOCK-APPLY.command`
2. Double-click on **Mac Hermes** (Tailscale up)

## If land hung / silent — diagnose only

1. Download **fresh** `HERMES-DIAGNOSE.command`
2. Double-click on Mac Hermes

Surfaces status even **without** `LINEAR_API_KEY`:
- `~/Desktop/HERMES-MAC-LAND-DIAG.txt` (+ clipboard)
- Opens Linear **RAL-800** + GitHub issue #1 for paste
- Linear comment if `~/.hermes/.env` has the key
- GitHub [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) if `gh` is logged in

## Terminal land (jsDelivr — copy from Linear/Notion, not Gmail)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh | bash
```

## Terminal diagnose

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/shared-scripts/hermes-moltbot-mac-land-diag.sh | bash
```

## Needs on Mac

- Tailscale up (or home LAN to `.11`)
- SSH BatchMode to `grok-cos-1` (`ilike4@100.92.147.61`)
- Fallback: if jump is down, land tries `.11` directly (`100.105.194.96` or LAN `192.168.1.11`)
- **No** private `moltbot` `gh` auth on Mac — jump/host clones tip

Optional: `LINEAR_API_KEY` in `~/.hermes/.env` for STARTED/FAILED/DIAGNOSTIC on RAL-800.

## Expect

RAL-800 (or issue #1): Mac land DIAGNOSTIC/STARTED → Host surgical-apply OK → RAL-793 Hermes CLAIMED.

No Slack rockets.
