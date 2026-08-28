# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-28T20:31:27Z

**Approve:** https://login.tailscale.com/a/1f410a5301cf93

Hard #115 rotate @ ~20:30Z (retired `1bcf51f9` / interim `11789ce2`). Soft restart often reissues the same URL — this wipe mints a fresh login.

**Ignore retired AuthURLs:** `1bcf51f9`, `1a1dd33b`, `16b94d1f`, `12e9ef58`, `184fd6d6`, `1953f34c`, `eeaef760`, `48641840`, …

Cloud waiters armed on Ooterverse pod. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Tip through **#122**. Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
