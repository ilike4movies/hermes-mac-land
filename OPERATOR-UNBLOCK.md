## Cloud wait-login → downstream (after Tailscale approve)

When a cloud agent is waiting on interactive Tailscale login and `HERMES_AUTO_SURGICAL_LAND=0`,
joining the mesh (`BackendState=Running`) auto-runs `hermes-dispatcher-downstream.sh`
(stalled-canary defaults) instead of surgical land — **only after** `HERMES_HOST_SSH_PRIVATE_KEY`
(+ `LINEAR_API_KEY`) is present. Waiters keep looping if Tailscale joins before secrets arrive
(Runtime Secrets / `/tmp/hermes-cloud-apply/host-ssh-key` / `/tmp/cursor/cloud-agent-secrets`); they do not one-shot-and-exit on Running alone. Tip **#103–#127**: on-join exports `COMPOSER_REPO_URL=hermes-mac-land`; join/supervisor/bridge poll `/tmp/cursor/cloud-agent-secrets`; on-join posts a one-shot #1 beacon when SSH arrives while still NeedsLogin (Linear RAL-823 fallback when `gh` blocked — #109); bridge default poll 10s; PENDING AuthURL tip sync (#110); hard AuthURL rotate helper when soft refresh reissues the same URL; wait-login single-instance flock + throttled NeedsLogin status (#112/#113); skip dead GH_TOKEN + AUTHURL_MCP_SURFACE_NEEDED (#114); ~45m refresh soft keep-alive by default (#123; hard opt-in); soft restart young-up guard (#117); curl|bash/ONE-SHOT-safe downstream entrypoint fetches part-a/b/c when missing (#118); Mac ONE-SHOT/STALL accept entrypoint (#119); tip-CDN pin fallback to known-good commit (#120); ONE-SHOT/STALL pin to #120 entrypoint SHA (#121). Jump-host ping is warn-only on the downstream-only path (direct `.11` SSH).

Interactive AuthURLs (~1h TTL) auto-refresh after ~45m while still NeedsLogin (`HERMES_TAILSCALE_AUTHURL_REFRESH_SECS`, default 2700) — see pod `CURRENT_AUTHURL.txt` and tip [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md). Soft `restart-authurl.sh` often **reissues the same** login URL — tip **#123** makes wait-login ~45m refresh **default SOFT keep-alive**; tip **#124** exports that soft default on supervisor wait-login respawn; tip **#125** skips soft remint while status still advertises a live AuthURL (avoids mid-approve link invalidation) so Gmail/RAL-823/Notion/tip approve links stay valid mid-wait. Opt in to hard wipe: `HERMES_AUTHURL_HARD_ON_REFRESH=1` or [`restart-authurl-hard.sh`](restart-authurl-hard.sh). `GH_TOKEN_INVALID` / `AUTHURL_MCP_SURFACE_NEEDED` no longer force hard (those flags only mean tip/beacon via MCP). Do **not** soft-kill a young `tailscale up` waiter (<~45m) — Soft `restart-authurl.sh` on tip now **refuses** young ups unless `HERMES_FORCE_AUTHURL_RESTART=1` (tip **#117**). Incomplete kills (EPERM on root-owned `up`) spawn a second `up` and mint a **new** AuthURL mid-approve; prefer attaching wait-login only. Tip **#110** keeps `PENDING_AUTHURL_TIP.txt` + local ICS aligned even if CURRENT was written out-of-band. Tip **#109**: secrets-ready on-join beacon falls back to Linear RAL-823 when `gh` is blocked. When `gh`/token can write, URL changes also auto-post to [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) (`HERMES_AUTHURL_GITHUB_BEACON=1`, default on; deduped via `LAST_POSTED_AUTHURL.txt`) and refresh tip [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md) + [`HERMES-APPROVE-TAILSCALE.ics`](HERMES-APPROVE-TAILSCALE.ics) for Mac ONE-SHOT (`HERMES_AUTHURL_TIP_FILE=1`, `HERMES_AUTHURL_TIP_ICS=1`). Linear AuthURL beacon needs `LINEAR_API_KEY` (`HERMES_AUTHURL_LINEAR_BEACON=1`). Cloud `GH_TOKEN` may be an expired installation token (`ghs_` → 401); tip/#114 writes `AUTHURL_MCP_SURFACE_NEEDED.txt` so agents use GitHub MCP instead of retrying dead tokens.


# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** Media Studio canary must show Hermes **CLAIMED** on live `.11` with inventory progress (do not put open canary ticket IDs in PR titles).

**Updated:** 2026-08-28T20:22Z

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

ONE-SHOT opens **Linear RAL-823** + **Tailscale admin + tip [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md)** + tip [`HERMES-APPROVE-TAILSCALE.ics`](HERMES-APPROVE-TAILSCALE.ics) early (`HERMES_ONE_SHOT_OPEN_TAILSCALE=0` to skip) so the Mac can approve the cloud waiter while STALL runs; then opens the GitHub Web UI workflow create + Raw paste tabs (`HERMES_ONE_SHOT_OPEN_WEBUI_EARLY=0` to skip). It also **auto-installs** the 5-min Downstream nag LaunchAgent (`HERMES_ONE_SHOT_INSTALL_NAG=0` to skip; auto-opens ONE-SHOT each tick unless `HERMES_NAG_AUTO_ONESHOT=0`) so the Mac keeps reminding until issue #1 shows `## Downstream DONE`. Inventory wait default is **900s** for ultra-stale canaries.

2. **Mac Terminal paste (same ONE-SHOT)** — when Finder Right-click is awkward:
   ```bash
   curl -fsSL -o ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command \
     && xattr -d com.apple.quarantine ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command \
     ; open ~/Downloads/HERMES-ONE-SHOT-UNBLOCK.command
   ```
3. **Mac STALL only** — [`HERMES-DOWNSTREAM-RAL793-STALL.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command) when Tailscale+SSH already known-good.
4. **Mac downstream nag** — installed automatically by ONE-SHOT (above). Standalone: **Right-click → Open** [`HERMES-INSTALL-DOWNSTREAM-NAG.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-INSTALL-DOWNSTREAM-NAG.command). LaunchAgent every 5 min: checks [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) for `## Downstream DONE`; if missing, spoken alert + macOS notification + opens issue #1 / ONE-SHOT / Web UI / Tailscale admin+tip AuthURL (`HERMES_NAG_OPEN_TAILSCALE=0` to skip), and **auto-downloads+opens ONE-SHOT** (`HERMES_NAG_AUTO_ONESHOT=0` for confirm dialog only). Never unattended DISPATCH. Auto-unloads on DONE. Uninstall: `launchctl unload ~/Library/LaunchAgents/com.hermes.downstream-nag.plist` then remove the plist and `~/.hermes/bin/hermes-downstream-nag.sh`.
5. **Web UI cloud agent** — repo `ilike4movies/hermes-mac-land`, env **LEGACY Hermes .11**, secrets at boot (`TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` + `LINEAR_API_KEY`)
6. **GitHub Actions** (durable; once enabled) — see [docs/CI-DOWNSTREAM-STALL.md](docs/CI-DOWNSTREAM-STALL.md) / [`ci/downstream-stall.yml`](ci/downstream-stall.yml)

### Enable GitHub Actions path (one-time, ~2 min)

API tokens often cannot write `.github/workflows/` (missing `workflows` scope). Prefer Mac local `gh` (ONE-SHOT Phase 2, or ENABLE launcher):

1. **Right-click → Open** [`HERMES-ONE-SHOT-UNBLOCK.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command) **or** [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ENABLE-DOWNSTREAM-ACTIONS.command)
   - Installs `ci/downstream-stall.yml` → `.github/workflows/downstream-stall.yml` on main
   - Runs `gh workflow run downstream-stall.yml`
   - If scope error: set `HERMES_GH_WORKFLOW_PAT` in `~/.hermes/.env` (tip **#126**/ONE-SHOT **#127**) or `gh auth refresh -h github.com -s workflow` then re-open
2. **Action secrets** (if not already set): Settings → Secrets and variables → Actions → `TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` + `LINEAR_API_KEY`
3. Or **web UI deep link** (no Mac / no API scope):
   - https://github.com/ilike4movies/hermes-mac-land/new/main?filename=.github%2Fworkflows%2Fdownstream-stall.yml
   - Paste Raw of [`ci/downstream-stall.yml`](ci/downstream-stall.yml) → commit to `main` → add Action secrets → Run workflow

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

## Live stall — run `2954673` (CLAIMED @ 23:25Z 2026-08-26, silent ~44h+)

| Item | Status |
|------|--------|
| Contract / inventory / Downstream DONE | **MISSING** |
| False Done @ 00:17Z | **REVERTED** — still open |

**Fastest tonight:** Mac Right-click → Open **ONE-SHOT**.command (STALL → Actions fallback), or Terminal paste above.

Stall defaults: `HERMES_AUTO_STACK_APPLY=0` + dual DISPATCH-NOW + **fail-closed if Linear key missing** + **inventory wait default 15 min** (`HERMES_INVENTORY_WAIT_SECS=900`). Runtime ~15–20 min (STALL inventory wait 900s) or Actions ~10–15 min. Watch [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1).

**Zombie reclaim (#72):** when stall age ≥1h (auto-detected from `HERMES_RUN_ID` prefix), downstream escalates to **3× DISPATCH-NOW @ 120s** for ultra-stale CLAIM — fail stale CLAIM → reopen → second reopen if still stuck. Mac launchers + `ci/downstream-stall.yml` (GHA template) default `HERMES_STALL_ZOMBIE=1` + `HERMES_STALL_ZOMBIE_PASSES=3` for run `2954673`. Track operator work on **RAL-823**.

## Program gates

| # | Requirement | Status |
|---|-------------|--------|
| 1–4 | Interrupt / apply / WIP-park / miss-idle | **DONE** |
| 5 | Media Studio canary + inventory | **OPEN** |
| 6 | Operator docs | **DONE** — tip through #127 (ONE-SHOT Phase 2 + ENABLE use HERMES_GH_WORKFLOW_PAT; soft skip remint while AuthURL live; supervisor soft keep-alive on wait-login respawn; AuthURL soft keep-alive default; ONE-SHOT pin to #120 entrypoint; tip-CDN pin fallback; curl|bash-safe entrypoint; soft restart young-up guard; sudo kill) |

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
