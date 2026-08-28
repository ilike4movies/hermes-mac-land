# CI downstream stall recovery

Credentialed GitHub→`.11` path that does **not** require Mac Right-click once enabled.

Source workflow (copyable): [`ci/downstream-stall.yml`](../ci/downstream-stall.yml)

## Why `ci/` not `.github/workflows/` yet

GitHub API tokens without the `workflows` scope cannot create files under `.github/workflows/` (returns 404). Enable once via the GitHub web UI (or a token with `workflow` scope).

## One-time enable (~2 min)

1. Open [`ci/downstream-stall.yml`](../ci/downstream-stall.yml)
2. Create `.github/workflows/downstream-stall.yml` on `main` with the same contents
3. Repo **Settings → Secrets and variables → Actions** — add:
   - `TS_AUTHKEY` — Tailscale auth key (ephemeral/reusable OK for CI)
   - `HERMES_HOST_SSH_PRIVATE_KEY` — PEM for BatchMode SSH to `.11`
   - `LINEAR_API_KEY` — required for fail-closed `DISPATCH-NOW`
4. **Actions → Downstream stall recovery → Run workflow**

Or CLI:

```bash
gh workflow run downstream-stall.yml --repo ilike4movies/hermes-mac-land
```

## What it runs

Same chain as Mac STALL.command / `hermes-dispatcher-downstream.sh`:

inspect → contract install → (stack-apply default skip) → dual `DISPATCH-NOW` → RAL-634 verify → inventory wait

Posts `## Downstream STARTED` / `DONE` / `FAILED` / `PARTIAL` to [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1).

## Until enabled

Use Mac STALL.command or LEGACY Hermes `.11` cloud agent. Do not spawn from Ooterverse.
