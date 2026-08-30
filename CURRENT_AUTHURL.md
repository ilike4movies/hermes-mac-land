# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-30T13:12:00Z

**Approve:** https://login.tailscale.com/a/1d0d805013867

Remint chain (do **not** use older links): `184ff33a` → `e064be30` → `6ad13a30` → **`1d0d8050`** (live). Forever `up --timeout=0s` armed. Tip through **#173** (Dropbox WAKE content refresh; #172 NAG Path C; #171 ONE-SHOT Path C). **Ignore retired** predecessors.

**Dropbox WAKE (public, tip#173 text):** [https://www.dropbox.com/scl/fi/t8p9b7qqnrrbrijhn1r1j/WAKE-1d0d8050-tip169.txt?rlkey=4p6zu480sotpw7lb34rjkbxli&dl=1](https://www.dropbox.com/scl/fi/t8p9b7qqnrrbrijhn1r1j/WAKE-1d0d8050-tip169.txt?rlkey=4p6zu480sotpw7lb34rjkbxli&dl=1)

Prefer **Mac ONE-SHOT** tip #173:

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

Expect `zombie=1 zombie_passes=3` + tip through **#173**. Success = GitHub #1 `## Downstream DONE @ <ts>` + `host=` + **live** RAL-793 inventory.

**Path C Zapier reconnects (Bad credentials / stale):**
- GitHub: [https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336](https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336)
- Google Calendar: [https://mcp.zapier.com/api/v1/connect-auth/GoogleCalendarCLIAPI?accountId=12547336&connectionId=55516487](https://mcp.zapier.com/api/v1/connect-auth/GoogleCalendarCLIAPI?accountId=12547336&connectionId=55516487)
Or Web UI paste Raw [`ci/downstream-stall.yml`](https://github.com/ilike4movies/hermes-mac-land/raw/main/ci/downstream-stall.yml) into [create workflow](https://github.com/ilike4movies/hermes-mac-land/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml).
