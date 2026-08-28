# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-28T21:18:53Z

**Approve:** https://login.tailscale.com/a/7a69b1a01e964

Soft #123/#124 refresh @ ~21:15Z (HARD=0) minted **7a69b1a0**. Tip **#125** skips soft remint while this AuthURL stays advertised — approve **this** URL. Tip **#126**: Mac ENABLE uses `HERMES_GH_WORKFLOW_PAT` from `~/.hermes/.env` for workflow write. Retired `1f410a53` (and older).

**Ignore retired AuthURLs:** `1f410a53`, `1bcf51f9`, `11789ce2`, `1a1dd33b`, `16b94d1f`, `12e9ef58`, `184fd6d6`, …

Cloud waiters armed on Ooterverse pod. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Tip through **#126**. Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
