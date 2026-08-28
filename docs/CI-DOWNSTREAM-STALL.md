# CI downstream stall recovery (draft)

This documents a planned `workflow_dispatch` path so credentialed downstream can run without Mac click once Action secrets are set.

## Required Action secrets

- `TS_AUTHKEY`
- `HERMES_HOST_SSH_PRIVATE_KEY`
- `LINEAR_API_KEY`

## Intended trigger

```bash
gh workflow run downstream-stall.yml --repo ilike4movies/hermes-mac-land
```

Until the workflow file lands (needs write to `.github/workflows`), use Mac STALL.command or LEGACY `.11` cloud agent.
