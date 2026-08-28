# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** Media Studio canary must show Hermes **CLAIMED** on live `.11` with inventory progress (do not put open canary ticket IDs in PR titles).

**Updated:** 2026-08-28T04:14Z

## ⚠️ Linear auto-Done hygiene

**Do NOT attach GitHub PRs to open canaries** while they are open — Linear auto-Dones on PR merge and falsely closes tickets before `.11` prove-out.

**Also:** do **not** put open canary ticket IDs in **PR titles** — GitHub auto-links on merge even when you do not attach manually.

| Incident | Cause | Fix |
|----------|-------|-----|
| 20:48Z | #18 merged + attached | Reverted; attachment detached @ 21:02Z |
| 21:29Z | #20 title contained canary ID → auto-attach | Reverted @ 21:30Z; attachment detached |
| 21:38Z | MCP comment used wrong issue UUID → posted on RAL-800 | Corrected @ 21:40Z; see UUID table below |
| 01:04Z | Cloud subagent `bc-3914e61d` booted on **Ooterverse** (not hermes-mac-land) | Downstream FAILED pre-SSH; use Mac or web-UI LEGACY `.11` agent |
| 03:49Z | #40 auto-attached to RAL-634 (Done) | Detach if needed; do not re-open RAL-634 for doc-only merges |
| 04:22Z | Cloud subagent `bc-cf21d38f` spawned from Ooterverse | Skipped downstream to avoid FAILED spam; use Mac or web-UI `hermes-mac-land` + LEGACY `.11` |
| 23:45Z | OPERATOR UUID table had RAL-799/RAL-820 swapped; RAL-798 missing | Corrected: RAL-798=`52e94e17…`, RAL-799=`0d76e06f…`, RAL-820=`144b087c…` |
| **00:17Z** | hermes-mac-land **#57** title contained canary ID → auto-Done @ 00:17:02Z | Status restored In Progress @ 00:18Z; attachment detached; PR title renamed |

## ⚠️ Ooterverse cloud agents cannot run downstream

**Do not spawn Hermes subagents from Ooterverse-Saturns-Quest** — they inherit the wrong repo/env and cannot receive `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` at boot.

**Paths that work for live gates:**
1. **Mac Hermes ONE-SHOT (preferred)** — **Right-click → Open** [`HERMES-ONE-SHOT-UNBLOCK.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command) (not double-click — Gatekeeper). Tries STALL downstream first; on fail auto-runs ENABLE-DOWNSTREAM-ACTIONS. Needs `LINEAR_API_KEY` in `~/.hermes/.env`.
2. **Mac Terminal paste (same ONE-SHOT)** — when Finder Right-click is awkward:
   ```bash
   curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command \
     && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command \
     ; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
   ```
3. **Mac STALL only** — [`HERMES-DOWNSTREAM-RAL793-STALL.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command) when Tailscale+SSH already known-good.
4. **Mac downstream nag (optional)** — **Right-click → Open** [`HERMES-INSTALL-DOWNSTREAM-NAG.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-INSTALL-DOWNSTREAM-NAG.command). LaunchAgent every 30 min: checks [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) for `## Downstream DONE`; if missing, macOS notification + opens issue #1 / ONE-SHOT download URL (does **not** auto-run ONE-SHOT). Auto-unloads on DONE. Uninstall: `launchctl unload ~/Library/LaunchAgents/com.hermes.downstream-nag.plist` then remove the plist and `~/.hermes/bin/hermes-downstream-nag.sh`.
5. **Web UI cloud agent** — repo `ilike4movies/hermes-mac-land`, env **LEGACY Hermes .11**, secrets at boot (`TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` + `LINEAR_API_KEY`)
6. **GitHub Actions** (durable; once enabled) — see [docs/CI-DOWNSTREAM-STALL.md](docs/CI-DOWNSTREAM-STALL.md) / [`ci/downstream-stall.yml`](ci/downstream-stall.yml)

### Enable GitHub Actions path (one-time, ~2 min)

API tokens often cannot write `.github/workflows/` (missing `workflows` scope). Prefer Mac local `gh` (ONE-SHOT Phase 2, or ENABLE launcher):

1. **Right-click → Open** [`HERMES-ONE-SHOT-UNBLOCK.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command) **or** [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ENABLE-DOWNSTREAM-ACTIONS.command)
   - Installs `ci/downstream-stall.yml` → `.github/workflows/downstream-stall.yml` on main
   - Runs `gh workflow run downstream-stall.yml`
   - If scope error: `gh auth refresh -h github.com -s workflow` then re-open
2. **Action secrets** (if not already set): Settings → Secrets and variables → Actions → `TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` + `LINEAR_API_KEY`
3. Or web UI: copy [`ci/downstream-stall.yml`](ci/downstream-stall.yml) → `.github/workflows/downstream-stall.yml` on main, then Run workflow

Expect `## Downstream STARTED` → `DONE` on [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1).

## Linear issue UUIDs (MCP / API comment posting)

| Ticket | UUID | Status |
|--------|------|--------|
| **RAL-793** | `963472c8-cc84-426a-9ed6-79e08566353a` | In Progress — **sole remaining program blocker** (stall `2954673`) |
| **RAL-634** | `1b5a7e86-1d14-456f-b0d1-39a02df243c2` | **Done** |
| **RAL-798** | `52e94e17-69e6-4688-a60e-aea25b090ebf` | In Progress — WIP-park **#110 LIVE** on `.11` (canary PASS @ 00:05Z) |
| **RAL-799** | `0d76e06f-bf49-4587-a733-1b6f397f1392` | **Done** |
| **RAL-800** | `dae80aa2-e6d0-4225-9ae8-cdb72ccd8ec0` | **Done** |
| **RAL-820** | `144b087c-79f2-4a31-aa21-a98357547843` | **Done** |
| **RAL-823** | `b444b07b-d9c5-496c-b5b0-79f31dd4d210` | In Progress — Mac ONE-SHOT operator wake (due 2026-08-28) |

## Live stall — run `2954673` (CLAIMED @ 23:25Z 2026-08-26, silent ~28h+)

| Item | Status |
|------|--------|
| Contract / inventory / Downstream DONE | **MISSING** |
| False Done @ 00:17Z | **REVERTED** — still open |

**Fastest tonight:** Mac Right-click → Open **ONE-SHOT**.command (STALL → Actions fallback), or Terminal paste above.

Stall defaults: `HERMES_AUTO_STACK_APPLY=0` + dual DISPATCH-NOW + **fail-closed if Linear key missing** + **inventory wait default 10 min** (`HERMES_INVENTORY_WAIT_SECS=600`, #71). Runtime ~10–15 min (STALL inventory) or Actions ~5–10 min. Watch [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1).

**Zombie reclaim (#72):** when stall age ≥1h (auto-detected from `HERMES_RUN_ID` prefix), downstream escalates to **3× DISPATCH-NOW @ 120s** for ultra-stale CLAIM — fail stale CLAIM → reopen → second reopen if still stuck. Mac launchers + `ci/downstream-stall.yml` (GHA template) default `HERMES_STALL_ZOMBIE=1` + `HERMES_STALL_ZOMBIE_PASSES=3` for run `2954673`. Track operator work on **RAL-823**.

## Program gates

| # | Requirement | Status |
|---|-------------|--------|
| 1–4 | Interrupt / apply / WIP-park / miss-idle | **DONE** |
| 5 | Media Studio canary + inventory | **OPEN** |
| 6 | Operator docs | **DONE** — #59–#73 (+ nag installer) |

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
