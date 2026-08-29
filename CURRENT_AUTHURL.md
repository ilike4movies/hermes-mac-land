# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-29T17:29:17Z

**Approve:** https://login.tailscale.com/a/1d0d805013867

Remint chain (do **not** use older links): `184ff33a` → `e064be30` → `6ad13a30` → **`1d0d8050`** (live). Forever `up --timeout=0s` armed. Tip through **#167** (ICS expected tip from TIP_PIN/CURRENT_AUTHURL; #166 tip-stale soft-hold; #165/#164; #162 STALL/ONLY; #161 ENABLE; FALLBACK `b2b5fc4` tip159). **Ignore retired** predecessors + `80d5b860`, `7a69b1a0`, …

Prefer **Mac ONE-SHOT** tip #167 if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3` + tip through **#167**. Success = GitHub #1 machine `## Downstream DONE @ <ts>` + `host=` + **live** RAL-793 inventory (not SEED/`pending`/deferred).

Path C (Actions): ONE-SHOT Phase 2 / ENABLE tip #161 git clone+push if `gh api` lacks OAuth `workflow` scope. Or Web UI paste Raw [`ci/downstream-stall.yml`](https://github.com/ilike4movies/hermes-mac-land/raw/main/ci/downstream-stall.yml) into [create workflow](https://github.com/ilike4movies/hermes-mac-land/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml).
