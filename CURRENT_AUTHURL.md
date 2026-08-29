# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-29T02:34:49Z

**Approve:** https://login.tailscale.com/a/184ff33a01912a

Live up `--timeout=14400s` nearing expiry (~03:03Z). Tip through **#135**: finite AuthURL hold-roll near expiry while AuthURL advertised (extends 14400s instead of forever remint / surprise expiry). Soft remint often keeps the same URL. Tip **#134** ICS 6h hold. Live AuthURL still **184ff33a**.

**Ignore retired AuthURLs:** `80d5b860`, `7a69b1a0`, `1f410a53`, `1bcf51f9`, `11789ce2`, `1a1dd33b`, `16b94d1f`, `12e9ef58`, `184fd6d6`, …

Cloud waiters armed. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
