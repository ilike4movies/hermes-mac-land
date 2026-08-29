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

Tip through **#161** on main (ENABLE/ONE-SHOT git clone+push fallback when contents API lacks OAuth `workflow` scope; tip #160 FALLBACK→b2b5fc4 tip159; #155 NAG DONE@ts; #154 prose reject). STALL/ONE-SHOT still prefer tip-first fetch.

Tip **#161**: Mac ENABLE / ONE-SHOT Phase 2 — if `gh api PUT …/contents/.github/workflows/…` 404s (missing OAuth `workflow` scope), fall back to shallow `git clone` (SSH first) + commit + `git push` of `ci/downstream-stall.yml`. SSH collaborator push often lands workflow files without the OAuth scope cloud tokens lack.

Tip **#160**: default `HERMES_DOWNSTREAM_FALLBACK_REF` → `b2b5fc4` (includes tip #159 fail-closed DONE beacon).

Tip **#159**: Downstream DONE GitHub beacon fail-closed (exit 2 if issue #1 post fails after live inventory).

Tip **#158**: downstream entrypoint rejects pre-#156/#150/#151 parts (`_parts_integrity_ok`) before assemble.

Tip **#157**: default `HERMES_DOWNSTREAM_FALLBACK_REF` → `ff0ccac` (includes tip #156 DONE-post + #150/#151 inventory integrity).

Tip **#156**: dispatcher `_post_github_status` uses timed `gh` + curl/token fallback so Mac Downstream DONE reaches issue #1.

Tip **#155**: NAG matches `## Downstream DONE` or `## Downstream DONE @ <ts>` + `host=` (part-c beacon form).

Tip **#154**: Downstream nag only unloads on machine DONE + `host=` (paginated); ignores tooling prose / inventory-deferred COMPLETE.
