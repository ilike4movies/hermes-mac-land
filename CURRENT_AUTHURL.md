# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-29T02:55Z

**Approve:** https://login.tailscale.com/a/1d0d805013867

Remint chain (do **not** use older links): `184ff33a` → `e064be30` → `6ad13a30` → **`1d0d8050`** (live). Forever `up --timeout=0s` armed. Tip **#136** ships single-flight hold-roll (persist `DESIRED_UP_TIMEOUT` + exclusive lock before kill+re-up; cold-start prefers finite while AuthURL live). **Ignore retired:** `1d0d8050` predecessors above plus `80d5b860`, `7a69b1a0`, `1f410a53`, …

Cloud waiters armed. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
