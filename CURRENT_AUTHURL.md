# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-28T22:19:09Z

**Approve:** https://login.tailscale.com/a/80d5b86015c32

`tailscale up --timeout=3600s` expired (~1h) → new AuthURL **80d5b860** (retired `7a69b1a0`). Tip **#125** soft-skip held the prior URL until the up process itself timed out — tip **#129** lengthens up timeout so soft-skip can hold approve links longer. Tip through **#129**.

**Ignore retired AuthURLs:** `7a69b1a0`, `1f410a53`, `1bcf51f9`, `11789ce2`, `1a1dd33b`, `16b94d1f`, `12e9ef58`, `184fd6d6`, …

Cloud waiters armed. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
