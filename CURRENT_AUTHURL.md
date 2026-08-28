# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-28T23:53:28Z

**Approve:** https://login.tailscale.com/a/184ff33a01912a

Tip **#130** controlled upgrade 3600s→14400s @ ~23:03Z soft-reminted AuthURL **184ff33a** (retired `80d5b860`). Live up still `--timeout=14400s`. Tip through **#134** (interactive up `--timeout=0` forever default; **#132** holds live AuthURL — no finite→forever remint while AuthURL advertised; **#133** single-flight downstream; **#134** AuthURL ICS hold **6h** + soft-hold tip ICS refresh before DTEND). Live AuthURL still **184ff33a**.

**Ignore retired AuthURLs:** `80d5b860`, `7a69b1a0`, `1f410a53`, `1bcf51f9`, `11789ce2`, `1a1dd33b`, `16b94d1f`, `12e9ef58`, `184fd6d6`, …

Cloud waiters armed. Prefer **Mac ONE-SHOT** if Runtime Secrets stay unset:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3`. Success = GitHub #1 `## Downstream DONE` + RAL-793 inventory.
