# Hermes Mac land (public bootstrap)

## Fastest — double-click

1. Open: https://github.com/ilike4movies/hermes-mac-land
2. Download a **fresh** `HERMES-UNBLOCK-APPLY.command`
3. Double-click on **Mac Hermes** (Tailscale up)

Gatekeeper:
`xattr -d com.apple.quarantine ~/Downloads/HERMES-UNBLOCK-APPLY.command && open ~/Downloads/HERMES-UNBLOCK-APPLY.command`

## Terminal (jsDelivr — copy from Linear/Notion, not Gmail)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh | bash
```

## Needs on Mac

- Tailscale up
- SSH BatchMode to `grok-cos-1` (`ilike4@100.92.147.61`)
- **No** private `moltbot` `gh` auth on Mac — jump host clones tip

Optional: `LINEAR_API_KEY` in `~/.hermes/.env` for early STARTED/FAILED on RAL-800.

## Expect

RAL-800: Mac land STARTED → Host surgical-apply OK → RAL-793 Hermes CLAIMED.

No Slack rockets.
