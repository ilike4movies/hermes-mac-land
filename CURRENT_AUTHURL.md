# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-28T21:18:53Z

**Approve:** https://login.tailscale.com/a/7a69b1a01e964

Soft #123/#124 ~45m refresh @ ~21:15Z (HARD=0). Soft keep-alive preferred the same URL; Tailscale minted a **new** login — approve **this** URL. Retired `1f410a53` (and older).

**Ignore retired AuthURLs:** `1f410a53`, `1bcf51f9`, `11789ce2`, `1a1dd33b`, `16b94d1f`, `12e9ef58`, `184fd6d6`, …

Cloud waiters armed on Ooterverse pod. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Tip through **#124**. Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
