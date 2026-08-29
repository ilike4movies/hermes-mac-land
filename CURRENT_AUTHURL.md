# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-29T02:50:00Z

**Approve:** https://login.tailscale.com/a/e064be3012df7

Tip **#135** finite hold-roll near expiry reminted AuthURL **184ff33a→e064be30** (duplicate wait-login race started forever=0). Live up now `--timeout=0s` (forever). Tip through **#135** on main. **Ignore retired:** `184ff33a`, `80d5b860`, `7a69b1a0`, `1f410a53`, `1bcf51f9`, …

Cloud waiters armed. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
