# Enable Downstream stall recovery (one-time)

Cloud/API tokens **cannot** create `.github/workflows/` files (GitHub Apps lack `workflows` scope → 404).

## Fastest — Mac ONE-SHOT

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

## No Mac — GitHub Web UI

1. Open (logged in as `ilike4movies`):
   **https://github.com/ilike4movies/hermes-mac-land/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml**
2. Paste Raw of [`ci/downstream-stall.yml`](ci/downstream-stall.yml)
3. Commit to `main`
4. Settings → Secrets and variables → Actions: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`, `LINEAR_API_KEY`
5. Actions → **Downstream stall recovery** → Run workflow

Watch [issue #1](../../issues/1) for `## Downstream DONE`.

Tip through **#155** on main (AuthURL beacon skips dead `gh` + MCP handoff dedupe). STALL/ONE-SHOT still prefer tip-first fetch.

Tip **#155**: Downstream nag only unloads on machine `## Downstream DONE` + `host=` (paginated); ignores tooling prose / inventory-deferred COMPLETE.

Tip **#155**: NAG matches `## Downstream DONE @ <ts>` + `host=` (part-c beacon form).
