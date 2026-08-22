# Hermes Mac land (public bootstrap)

## Fastest — double-click (no Terminal paste, no Gmail)

1. Open: https://github.com/ilike4movies/hermes-mac-land
2. Download **`HERMES-UNBLOCK-APPLY.command`** (raw / Download file)
3. Double-click it on **Mac Hermes** (Tailscale up)

If macOS blocks it: right-click → Open, or in Terminal:
`xattr -d com.apple.quarantine ~/Downloads/HERMES-UNBLOCK-APPLY.command && open ~/Downloads/HERMES-UNBLOCK-APPLY.command`

## Or paste ONE LINE in Terminal

Prefer jsDelivr (avoids stale `raw.githubusercontent.com` CDN):

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh | bash
```

Fallback (GitHub raw tip SHA if CDN lags):

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/36c63390adbad78aff48884b90ed8e0c8bc4b7ad/hermes-mac-land.sh | bash
```

**Do not copy curl from Gmail** — Gmail rewrites URLs through `google.com/url?q=...` and breaks paste. Copy from Linear RAL-800, Notion, or this README.

## Needs

- Tailscale up
- SSH BatchMode to `grok-cos-1`
- `gh auth` (or git SSH/HTTPS) to private `ilike4movies/moltbot`
- Optional: `LINEAR_API_KEY` in `~/.hermes/.env` so failed Mac attempts still post STARTED/FAILED on RAL-800 before tip fetch

## Expect

Linear RAL-800: Mac land STARTED (early from public bootstrap) → Host surgical-apply OK → RAL-793 Hermes CLAIMED.

No Slack rockets.
