# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` (`four-openclaw`) **with inventory progress**. GitHub `main` alone is not sufficient.

**Updated:** 2026-08-25T20:38Z

## ⚠️ moltbot PR #76 — do not merge yet

[`moltbot` PR #76](https://github.com/ilike4movies/moltbot/pull/76) is **linked in Linear to RAL-820 and RAL-793**. Merging while attached may auto-Done those issues before live `.11` proof.

Land scripts on `hermes-mac-land` `main` already export `HERMES_POST_APPLY_CANARY=RAL-820` — merge PR #76 only after detaching from canary issues or after canary proof.

## RAL-798 source update (20:24Z)

PR [#82](https://github.com/ilike4movies/hermes-agent-cos/pull/82) merged to `cos-local` (`cef81c9`):
- `DISPATCH-NOW` comments discoverable without `hermes-now` label
- Fresh comment interrupts rank before standing labels
- Unresolved standing labels skipped when resolvable interrupt exists

**Next:** bounded Stage A live retry on `.11` with PR #82 merged code (not yet run). Existing `DISPATCH-NOW RAL-820` comment from 20:13Z should be discovered after deploy. RAL-820 canary still open.

## Current live state (readback)

| Check | Status |
|-------|--------|
| RAL-820 successor canary (`subject.txt` → `executed`) | **Open** — rolled back 20:16Z; Stage A retry pending |
| RAL-798 interrupt → executor | **Source fixed** (PR #82 merged) — live Stage A retry pending on `.11` |
| RAL-800 Host surgical-apply OK | **No** — moltbot tip stack not landed via surgical apply |
| RAL-793 CLAIMED + inventory | **No** — accidental claim reverted 20:15Z; gated behind RAL-820 + own contract |

**Important:** A brief RAL-793 CLAIMED at 20:14–20:15Z was an RAL-798 Stage A accident (stale `hermes-now`). No executor ran. Issue returned to **Todo**. Do not treat it as canary success.

## Dependency order

1. **RAL-820** — harmless fixture canary proves interrupt → real executor movement
2. **RAL-798** — interrupt contract Done (label + comment + contract resolution)
3. **RAL-800** — moltbot tip stack on `.11` via surgical apply (GitHub→host path + drift alarms)
4. **RAL-793** — Media Studio inventory (needs own execution contract; not `hermes-now` until reviewed)

Two parallel tracks exist today:
- **RAL-798** (`hermes-agent-cos`): in-place Stage A patches on live `.11` dispatcher
- **RAL-800** (`moltbot` via this repo): surgical apply lands full tip stack from GitHub `main`

Either path can advance interrupt work; RAL-800 is still required for ongoing GitHub→host apply + drift alarms.

## Pick one path

### A — New cloud agent (preferred)

1. **Web UI only** (not mobile) → repo **`ilike4movies/hermes-mac-land`**
2. Environment: **LEGACY Hermes .11 — do not use for Ooterverse**
3. **Runtime Secrets at agent boot** (not mid-session): `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`
4. `.cursor/environment.json` on `main` auto-runs surgical land when secrets present

**Pitfalls:** Mobile cloud agents and Ooterverse override envs do **not** get Hermes secrets at boot. Internal subagents cannot receive Runtime Secrets mid-session.

### B — Resume verified agent

https://cursor.com/agents/bc-458cf08d-4954-411a-978a-de2adb650e33

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
HERMES_PREFER_DIRECT_HOST=1 bash /tmp/hermes-cloud-apply/hermes-moltbot-cloud-apply-install-via-ssh.sh
```

Credentials verified 2026-08-22 17:36Z. Surgical land was **not** run in that session.

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
5. `post-apply canary focus: RAL-820` (not RAL-793)
6. RAL-800 → **Host surgical-apply OK**
7. RAL-820 → `subject.txt` = `executed` (RAL-798 canary)
8. RAL-793 → Hermes **CLAIMED** + inventory (only after RAL-820 + own contract)

## Do not use

- Slack rockets as primary wake path
- Ooterverse-Saturns-Quest repo/env for Hermes deploy (game-only since PR #9)
- `hermes-now` on RAL-793 until RAL-820 proves interrupt + contract exists
- Internal cloud subagents without secrets at boot
- Merging `moltbot` PR #76 while linked to RAL-820/RAL-793 in Linear
- `git reset --hard` on `/opt/moltbot`
- `git pull --ff-only` on dirty/no-origin `/opt/moltbot` (use surgical-apply)

## Repos

| Repo | Role |
|------|------|
| `ilike4movies/hermes-mac-land` | Public Mac/cloud land scripts (this repo) |
| `ilike4movies/moltbot` | Private dispatcher stack (cos-linear-dispatcher, surgical-apply) |
| `ilike4movies/hermes-agent-cos` | RAL-798 control-loop adapter (Stage A on `.11`) |
