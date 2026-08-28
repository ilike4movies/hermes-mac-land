# CI downstream stall recovery

Credentialed GitHub→`.11` path that does **not** require Mac Right-click once enabled.

Source workflow (copyable): [`ci/downstream-stall.yml`](../ci/downstream-stall.yml)

## Why `ci/` not `.github/workflows/` yet

GitHub API tokens without the `workflows` scope cannot create files under `.github/workflows/` (returns 404). Enable once via:

1. **Mac (preferred):** Right-click → Open [`HERMES-ONE-SHOT-UNBLOCK.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command) (Phase 2) or [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ENABLE-DOWNSTREAM-ACTIONS.command) — uses local `gh` (refresh with `gh auth refresh -h github.com -s workflow` if needed), installs the workflow, then runs it.
2. GitHub web UI paste (below)
3. A PAT / `gh` token that includes the `workflow` scope

## One-time enable (~2 min)

### A — Mac enable launcher

1. Download [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ENABLE-DOWNSTREAM-ACTIONS.command)
2. **Right-click → Open**
3. If install fails on scope: `gh auth refresh -h github.com -s workflow` then re-open
4. Ensure Action secrets exist (launcher opens the secrets settings page on run failure)

### B — Web UI

1. Open [`ci/downstream-stall.yml`](../ci/downstream-stall.yml)
2. Create `.github/workflows/downstream-stall.yml` on `main` with the same contents
3. Repo **Settings → Secrets and variables → Actions** — add:
   - `TS_AUTHKEY` — Tailscale auth key (ephemeral/reusable OK for CI)
   - `HERMES_HOST_SSH_PRIVATE_KEY` — PEM for BatchMode SSH to `.11`
   - `LINEAR_API_KEY` — required for fail-closed `DISPATCH-NOW`
4. **Actions → Downstream stall recovery → Run workflow**

Or CLI (after workflow file exists):

```bash
gh workflow run downstream-stall.yml --repo ilike4movies/hermes-mac-land
```

## What it runs

Same chain as Mac STALL.command / `hermes-dispatcher-downstream.sh`:

inspect → contract install → (stack-apply default skip) → dual/`zombie` `DISPATCH-NOW` → RAL-634 verify → inventory wait (default 600s)

GHA template defaults: `HERMES_STALL_ZOMBIE=1`, `HERMES_STALL_ZOMBIE_PASSES=3`, `HERMES_INVENTORY_WAIT_SECS=600`, timeout 25m.

Posts `## Downstream STARTED` / `DONE` / `FAILED` / `PARTIAL` to [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1).

## Until enabled / for tonight's stalled canary

**Mac Terminal paste (ONE-SHOT):**

```bash
curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command \
  && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command \
  ; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
```

If Mac already has Tailscale + SSH to `.11` + `LINEAR_API_KEY`, prefer [`HERMES-DOWNSTREAM-RAL793-STALL.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command) (faster; no Action secrets needed).

Otherwise use LEGACY Hermes `.11` cloud agent. Do not spawn from Ooterverse.
