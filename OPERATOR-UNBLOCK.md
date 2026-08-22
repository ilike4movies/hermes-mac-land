# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` (`four-openclaw`). GitHub `main` alone is not sufficient.

## Status checklist

| Check | How to verify |
|-------|----------------|
| RAL-793 CLAIMED + inventory | Linear issue RAL-793 |
| RAL-800 Host surgical-apply OK | Machine comment on RAL-800 |
| Live `.11` tip stack | `OK INTERRUPT_LABEL hermes-now` in land output |

## Pick one path

### A — New cloud agent (preferred after 2026-08-22 scope separation)

1. **Web UI** (not mobile) → repo **`ilike4movies/hermes-mac-land`**
2. Environment: **LEGACY Hermes .11 — do not use for Ooterverse**
3. Runtime Secrets at boot: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`
4. `.cursor/environment.json` on `main` auto-runs surgical land when secrets present

### B — Resume verified agent

https://cursor.com/agents/bc-458cf08d-4954-411a-978a-de2adb650e33

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
HERMES_PREFER_DIRECT_HOST=1 bash /tmp/hermes-cloud-apply/hermes-moltbot-cloud-apply-install-via-ssh.sh
```

### C — Mac Hermes (home LAN / Tailscale)

```bash
gh auth login
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
```

Optional in `~/.hermes/.env`: `HERMES_HOST_SSH_PRIVATE_KEY` (PEM for BatchMode SSH to `.11`).

## Success markers (in order)

1. `INFO: HERMES_PREFER_DIRECT_HOST=1 — skipping jump`
2. `== fetching moltbot tip via gh tarball (caller) ==`
3. `== uploading tip tarball to ilike4@…`
4. `OK INTERRUPT_LABEL hermes-now`
5. RAL-800 → **Host surgical-apply OK**
6. RAL-793 → Hermes **CLAIMED** within ~5m

## Do not use

- Slack rockets
- Ooterverse-Saturns-Quest repo for Hermes deploy (game-only since PR #9)
- Internal cloud subagents without secrets at boot
- `git reset --hard` on `/opt/moltbot`

## Repos

| Repo | Role |
|------|------|
| `ilike4movies/hermes-mac-land` | Public Mac/cloud land scripts |
| `ilike4movies/moltbot` | Private dispatcher stack (cos-linear-dispatcher, surgical-apply) |
