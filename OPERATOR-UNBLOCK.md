## Cloud wait-login → downstream (after Tailscale approve)

When a cloud agent is waiting on interactive Tailscale login and `HERMES_AUTO_SURGICAL_LAND=0`,
joining the mesh (`BackendState=Running`) auto-runs `hermes-dispatcher-downstream.sh`
(stalled-canary defaults) instead of surgical land — **only after** `HERMES_HOST_SSH_PRIVATE_KEY`
(+ `LINEAR_API_KEY`) is present. Waiters keep looping if Tailscale joins before secrets arrive
(Runtime Secrets / `/tmp/hermes-cloud-apply/host-ssh-key` / `/tmp/cursor/cloud-agent-secrets`); they do not one-shot-and-exit on Running alone. Tip **#103–#133**: on-join exports `COMPOSER_REPO_URL=hermes-mac-land`; join/supervisor/bridge poll `/tmp/cursor/cloud-agent-secrets`; on-join posts a one-shot #1 beacon when SSH arrives while still NeedsLogin (Linear RAL-823 fallback when `gh` blocked — #109); bridge default poll 10s; PENDING AuthURL tip sync (#110); hard AuthURL rotate helper when soft refresh reissues the same URL; wait-login single-instance flock + throttled NeedsLogin status (#112/#113); skip dead GH_TOKEN + AUTHURL_MCP_SURFACE_NEEDED (#114); ~45m refresh soft keep-alive by default (#123; hard opt-in); soft restart young-up guard (#117); curl|bash/ONE-SHOT-safe downstream entrypoint fetches part-a/b/c when missing (#118); Mac ONE-SHOT/STALL accept entrypoint (#119); tip-CDN pin fallback to known-good commit (#120); ONE-SHOT/STALL pin to #120 entrypoint SHA (#121). Jump-host ping is warn-only on the downstream-only path (direct `.11` SSH).

Interactive AuthURLs (~1h TTL) auto-refresh after ~45m while still NeedsLogin (`HERMES_TAILSCALE_AUTHURL_REFRESH_SECS`, default 2700) — see pod `CURRENT_AUTHURL.txt` and tip [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md). Soft `restart-authurl.sh` often **reissues the same** login URL — tip **#123** makes wait-login ~45m refresh **default SOFT keep-alive**; tip **#124** exports that soft default on supervisor wait-login respawn; tip **#125** skips soft remint while status still advertises a live AuthURL (avoids mid-approve link invalidation) so Gmail/RAL-823/Notion/tip approve links stay valid mid-wait; tip **#128** throttles the soft-skip OK echo to `HERMES_WAIT_LOGIN_STATUS_EVERY_SECS` (default 60s) so wait-login logs stay small. Tip **#129** defaults interactive `tailscale up --timeout` to **4h** (`HERMES_TAILSCALE_LOGIN_WAIT_SECS=14400`) so #125 soft-skip can hold the same AuthURL past the old 1h up expiry (which reminted `7a69b1a0`→`80d5b860` @ ~22:18Z). Tip **#130** upgrades leftover short-timeout ups (e.g. still-running `--timeout=3600s`) to the desired 4h window near expiry (`HERMES_TAILSCALE_UP_UPGRADE_LEAD_SECS`, default 900) instead of soft-skipping until surprise remint; disable with `HERMES_TAILSCALE_UP_UPGRADE_SHORT=0`. Tip **#131** defaults interactive `tailscale up --timeout` to **0s (forever)** (`HERMES_TAILSCALE_UP_TIMEOUT_SECS=0`) so soft-skip can hold AuthURL without up-process expiry remints; script-level wait stays `HERMES_TAILSCALE_LOGIN_WAIT_SECS=14400`. Tip **#132** skips finite→forever soft upgrades while status still advertises a live AuthURL (tip#130 upgrade reminted `80d5b860`→`184ff33a`); forever-up starts only after AuthURL is gone (or `HERMES_AUTHURL_FORCE_REFRESH=1`). Tip **#133**; tip **#134**; tip **#135** (finite AuthURL hold-roll near expiry while AuthURL live — avoid forever/expiry remint); tip **#136** (persist `DESIRED_UP_TIMEOUT` + exclusive up-lock before kill+re-up; cold-start prefers finite while AuthURL live — stops sibling forever=0 remint); tip **#137** (`hermes-cloud-attach-wait-login.sh` attach-only respawn — never pkill-self / never kill live up; supervisor adopts DESIRED_UP_TIMEOUT on spawn); tip **#138** (attach+supervisor share `$DIR/wait-login.flock`; attach no-op when one healthy wait+up holds live AuthURL — stops attach↔supervisor duplicate spawn remints); tip **#139** (ONE-SHOT RAL-823 AuthURL-1d0d8050 slug + tip banner; workflow still Web UI/PAT); tip **#140** (Running-without-SSH once-beacon to #1/RAL-823); tip **#141** (secrets-bridge `-f` bash + heartbeat) (AuthURL ICS hold default **6h** via `HERMES_AUTHURL_ICS_HOLD_HOURS`, soft-hold tip ICS refresh when DTEND within `HERMES_AUTHURL_ICS_REFRESH_REMAIN_SECS` default 1800s) single-flight credentialed downstream (`hermes-cloud-run-downstream-once.sh`: flock + success-only marker) so wait-login/supervisor/on-join do not triple-run stall, and transient FAIL can retry. Opt in to hard wipe: `HERMES_AUTHURL_HARD_ON_REFRESH=1` or [`restart-authurl-hard.sh`](restart-authurl-hard.sh). `GH_TOKEN_INVALID` / `AUTHURL_MCP_SURFACE_NEEDED` no longer force hard (those flags only mean tip/beacon via MCP). Do **not** soft-kill a young `tailscale up` waiter (<~45m) — Soft `restart-authurl.sh` on tip now **refuses** young ups unless `HERMES_FORCE_AUTHURL_RESTART=1` (tip **#117**). Incomplete kills (EPERM on root-owned `up`) spawn a second `up` and mint a **new** AuthURL mid-approve; prefer attaching wait-login only. Tip **#110** keeps `PENDING_AUTHURL_TIP.txt` + local ICS aligned even if CURRENT was written out-of-band. Tip **#109**: secrets-ready on-join beacon falls back to Linear RAL-823 when `gh` is blocked. When `gh`/token can write, URL changes also auto-post to [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) (`HERMES_AUTHURL_GITHUB_BEACON=1`, default on; deduped via `LAST_POSTED_AUTHURL.txt`) and refresh tip [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md) + [`HERMES-APPROVE-TAILSCALE.ics`](HERMES-APPROVE-TAILSCALE.ics) for Mac ONE-SHOT (`HERMES_AUTHURL_TIP_FILE=1`, `HERMES_AUTHURL_TIP_ICS=1`). Linear AuthURL beacon needs `LINEAR_API_KEY` (`HERMES_AUTHURL_LINEAR_BEACON=1`). Cloud `GH_TOKEN` may be an expired installation token (`ghs_` → 401); tip/#114 writes `AUTHURL_MCP_SURFACE_NEEDED.txt` so agents use GitHub MCP instead of retrying dead tokens.


# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** Media Studio canary must show Hermes **CLAIMED** on live `.11` with inventory progress (do not put open canary ticket IDs in PR titles).

**Updated:** 2026-08-29T04:52Z

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
| 6 | Operator docs | **DONE** — tip through #176 (NAG Raw+secrets Path C; #175–#160)|

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse


### Tip #136 (AuthURL single-flight hold-roll)

- Persist `DESIRED_UP_TIMEOUT.txt` on tip#135 finite hold-roll so sibling wait-login does not cold-start `forever=0` mid-roll (proven remint `184ff33a→e064be30`).
- Take exclusive `tailscale-up` flock **before** kill+re-up.
- Cold-start while AuthURL still advertised prefers finite `LOGIN_WAIT` (14400s) over forever unless `HERMES_AUTHURL_FORCE_FOREVER_START=1` (forever cold-start reminted `e064be30→6ad13a30`).

### Tip #137 (attach-only wait-login)

- Prefer [`shared-scripts/hermes-cloud-attach-wait-login.sh`](shared-scripts/hermes-cloud-attach-wait-login.sh) over `restart-authurl.sh` / manual `tailscale up` while NeedsLogin still advertises a live AuthURL.
- Kills wait-login by exact PID only (no `pkill -f` self-match). Never kills interactive `up` unless `HERMES_FORCE_KILL_UP=1`.
- Refuses cold-start when AuthURL is live and no up is running (`HERMES_FORCE_COLD_UP=1` to override — expect remint).
- Supervisor spawn adopts `DESIRED_UP_TIMEOUT.txt` (tip #136) so respawns do not reintroduce forever=0 mid-roll.

### Tip #138 (attach+supervisor share wait-login flock)

- [`hermes-cloud-attach-wait-login.sh`](shared-scripts/hermes-cloud-attach-wait-login.sh) and [`hermes-cloud-wait-login-supervisor.sh`](shared-scripts/hermes-cloud-wait-login-supervisor.sh) both take `$DIR/wait-login.flock` before spawning `--wait-login`.
- Attach is a **no-op** when exactly one healthy wait-login + forever/`timeout=0s` up already holds a live AuthURL (no kill, no remint). Force with `HERMES_FORCE_REATTACH=1`.
- Supervisor skips spawn when the flock is busy or a waiter is already active under the flock.
- Stops the attach↔supervisor race that reminted AuthURLs after tip #137 (duplicate wait-logins @ ~03:17Z).

### Tip #139 (ONE-SHOT RAL-823 URL + tip banner)

- [`HERMES-ONE-SHOT-UNBLOCK.command`](HERMES-ONE-SHOT-UNBLOCK.command) Linear default URL points at live RAL-823 slug (`…authurl-1d0d8050-canary`), not the retired `…silent-36h` slug.
- Banner notes tip through #138 AuthURL hold flock so Mac operators open CURRENT_AUTHURL / RAL-823 first.
- `.github/workflows/downstream-stall.yml` still requires Mac/`HERMES_GH_WORKFLOW_PAT`/Web UI (GitHub App 404 on workflows scope). Source of truth remains [`ci/downstream-stall.yml`](ci/downstream-stall.yml).

### Tip #140 (Running-without-SSH beacon)

- [`hermes-downstream-on-join-watcher.sh`](shared-scripts/hermes-downstream-on-join-watcher.sh): when BackendState is `Running` but `HERMES_HOST_SSH_PRIVATE_KEY` is still missing, post **once** to GitHub #1 / Linear RAL-823 (and write `RUNNING_NO_SSH_MCP_SURFACE_NEEDED.txt` for agents when gh/token blocked).
- Makes approve-without-secrets visible instead of silent 30s wait loops. Mac ONE-SHOT remains preferred when Runtime Secrets stay unset on Ooterverse.

### Tip #141 (secrets-bridge `-f` + heartbeat)

- [`hermes-cloud-secrets-bridge-poller.sh`](shared-scripts/hermes-cloud-secrets-bridge-poller.sh): run bridge scripts with `bash` when the file **exists**, not only when `+x` (curl|raw downloads often land `0644`). Prefer tip-named `hermes-moltbot-cloud-bridge-secrets-from-env.sh`.
- Heartbeat every `HERMES_SECRETS_BRIDGE_HEARTBEAT_EVERY` polls (default 30 ≈5m at 10s interval) so log mtime proves the poller is alive.
- Live bug: poller pid stayed up for 12h+ but never invoked the bridge because `-x` failed — mid-session Runtime Secrets would not arm waiters until this tip.

### Tip #142 (run-downstream-once bash + tip CDN fetch)

- [`hermes-cloud-run-downstream-once.sh`](shared-scripts/hermes-cloud-run-downstream-once.sh): resolve dispatcher with `-f`+`bash` (not `-x`-only); if missing locally, curl tip CDN `shared-scripts/hermes-dispatcher-downstream.sh` before fail-closed exit 127.
- Prevents post-approve on-join/wait-login stall from aborting after AuthURL join when apply-dir scripts are 0644 or not yet synced.

### Tip #143 (on-join/supervisor once `-f` + CDN)

- [`hermes-downstream-on-join-watcher.sh`](shared-scripts/hermes-downstream-on-join-watcher.sh), [`hermes-cloud-wait-login-supervisor.sh`](shared-scripts/hermes-cloud-wait-login-supervisor.sh), [`hermes-join-part-c.sh`](shared-scripts/hermes-join-part-c.sh): resolve `hermes-cloud-run-downstream-once.sh` with `-f` (+ tip CDN fetch), not `-x`-only.
- Closes the tip#141/#142 class gap at the caller: 0644 once launcher no longer skips post-approve stall.

### Tip #144 (supervisor/start/join `-f` for bridge + poller)

- `hermes-cloud-wait-login-supervisor.sh`, `hermes-cloud-bootstrap-waiter.sh`, `hermes-cloud-agent-start.sh`, join/wait-join, and `hermes-credentialed-resume-land.sh` now start bridge + secrets-bridge-poller via **`-f` + bash (+ CDN)**, not `-x`-only.
- Closes the tip#141 class gap at the **caller**: a 0644 poller/bridge download no longer silently skips mid-session Runtime Secrets while AuthURL is held.

### Tip #145 (dispatcher helpers `-f` + CDN)

- `hermes-dispatcher-part-a.sh` / `part-b.sh`: resolve contract/inspect/starve/stack-apply via **`-f`**, fetch on missing, always `chmod +x` before `bash` (0644 curl class).
- `hermes-cloud-agent-start.sh` + `hermes-credentialed-resume-land.sh`: prefer tip#142 once launcher; `-f`+CDN for downstream helpers.
- Closes the tip#141–#144 class gap on the **credentialed stall chain** itself so Mac ONE-SHOT / post-approve once launcher cannot skip helpers that landed mode 0644.

### Tip #146 (ONE-SHOT prefers tip once + main)

- [`HERMES-ONE-SHOT-UNBLOCK.command`](HERMES-ONE-SHOT-UNBLOCK.command): Phase 1 STALL now prefers tip **#142** `hermes-cloud-run-downstream-once.sh`, then tip/`main` dispatcher entrypoint.
- Removes default stale `HERMES_DOWNSTREAM_PIN` that pinned a pre-#145 SHA ahead of tip (set explicitly only if needed).
- Banner pinned through **#145+**. Ensures Mac ONE-SHOT picks up tip#145 `-f` helper resolve without CDN-lag pin games.

### Tip #147 (STALL.command tip once + main)

- [`HERMES-DOWNSTREAM-RAL793-STALL.command`](HERMES-DOWNSTREAM-RAL793-STALL.command): same tip#146 class fix — prefer tip#142 once launcher, then tip/`main`; drop stale `a657c617…` pin default.
- Closes the alternate Mac double-click path that still skipped tip#145 `-f` helpers.

### Tip #148 (DOWNSTREAM-ONLY stall-class parity)

- [`HERMES-DOWNSTREAM-ONLY.command`](HERMES-DOWNSTREAM-ONLY.command): now matches STALL/ONE-SHOT stall-class defaults — pin run `2954673`, `HERMES_AUTO_SURGICAL_LAND=0`, zombie=`1`/`3`, `WAIT_INVENTORY=1`, Linear key preflight, tip#142 once launcher first.
- Closes the third Mac entrypoint that previously ran bare dispatcher without stall recovery / inventory wait.

### Tip #149 (Stage A preflight `-f`, not `-x`)

- [`hermes-cloud-agent-start.sh`](shared-scripts/hermes-cloud-agent-start.sh) + [`hermes-moltbot-cloud-wait-join-then-apply.sh`](shared-scripts/hermes-moltbot-cloud-wait-join-then-apply.sh): Stage A source/live preflight now resolve with `-f` + `chmod +x` before `bash` (0644 curl class).
- Closes the tip#141–#145 class gap left on the **post-surgical-land Stage A** path (credentialed-resume already fixed in #145).

### Tip #150 (inventory-wait rejects contract-install SEED)

- [`hermes-dispatcher-part-b.sh`](shared-scripts/hermes-dispatcher-part-b.sh) `_inventory_evidence_ok`: reject `pending` first line + `SEED` / `NOT live inventory` markers **before** accepting EP04/workspace/tts keywords.
- Proven false-pass: tip#97 SEED embeds `/opt/moltbot`, `tts`, `EP04` in comments → old check returned OK and could mark Downstream DONE without live inventory.
- Live accept requires dated LIVE / sha / host-verify signals (or EP + real `work/ep` artifact paths), not archaeology prose.

### Tip #151 (DONE requires live inventory present)

- [`hermes-dispatcher-part-c.sh`](shared-scripts/hermes-dispatcher-part-c.sh): bare `## Downstream DONE` only when `inventory wait: present` (INVENTORY_STATUS=present + STARVE_RC=0).
- `HERMES_WAIT_INVENTORY=0` no longer posts bare DONE with `skipped` — posts `## Downstream COMPLETE (inventory deferred)` instead so obj5 cred_DONE gates cannot false-count.
- Inventory miss/timeout still posts `## Downstream PARTIAL` + non-zero exit (tip#150 SEED reject remains the wait gate).

### Tip #152 (FALLBACK pin includes tip #150/#151)

- [`hermes-dispatcher-downstream.sh`](shared-scripts/hermes-dispatcher-downstream.sh): default `HERMES_DOWNSTREAM_FALLBACK_REF` bumped `dc1980b` (#118) → **`6c6881a`** (tip #151).
- CDN fail on `main` must not assemble pre-#150/#151 parts (SEED false-pass / bare DONE with inventory skipped).

### Tip #153 (AuthURL beacon: skip dead gh + MCP handoff dedupe)

- [`hermes-join-part-b.sh`](shared-scripts/hermes-join-part-b.sh): auto-beacon **skips `gh`** when `GH_TOKEN_INVALID.flag` is set; wraps `gh` in `timeout` (default 8s); first gh 401 sets the invalid flag.
- Tip CURRENT_AUTHURL.md / ICS tip puts also skip `gh` when the flag is set (curl path already did).
- When beacon cannot post (dead ghs_/no Linear key), writing `AUTHURL_MCP_SURFACE_NEEDED.txt` also records the URL into `LAST_POSTED_AUTHURL.txt` so wait-login does **not** re-run dead `gh` every poll while `LAST_POSTED` still holds a retired remint (e.g. `80d5b860` vs live `1d0d8050`).
- Remint still re-beacons (URL change ≠ lastfile). Agent clears MCP surface after tip/#1/RAL-823 MCP post.

### Tip #154 (NAG: machine Downstream DONE only)

- [`HERMES-INSTALL-DOWNSTREAM-NAG.command`](HERMES-INSTALL-DOWNSTREAM-NAG.command): stop matching prose substring `## Downstream DONE` (42+ tooling hits on issue #1 page 1 → false unload).
- Require **first line exact** `## Downstream DONE` **and** `host=` in body (credentialed machine beacon).
- Curl path **paginates** all comment pages (issue #1 >100 comments); `gh --paginate` unchanged.
- Explicitly ignores `## Downstream COMPLETE (inventory deferred)` (tip #151) so nag keeps firing until live inventory DONE.

### Tip #155 (NAG matches timestamped Downstream DONE)

- Part-c machine beacons post `## Downstream DONE @ $WHEN` (not bare `## Downstream DONE`).
- Tip #154 exact-line match would **never unload** after real success — tip #155 accepts `## Downstream DONE` **or** `## Downstream DONE @ …` first line + `host=`.
- [`HERMES-ONE-SHOT-UNBLOCK.command`](HERMES-ONE-SHOT-UNBLOCK.command): nag install requires `_machine_downstream_done` + `Downstream DONE @` so stale pre-#154/#155 NAG is not reinstalled from CDN.

### Tip #156 (Downstream status post: timeout gh + curl fallback)

- [`hermes-dispatcher-part-a.sh`](shared-scripts/hermes-dispatcher-part-a.sh) `_post_github_status`: was gh-only, silent fail — Mac ONE-SHOT/STALL could finish inventory wait and still leave issue #1 without `## Downstream DONE @ …` (obj5 gates + tip#154/#155 NAG never see success).
- Now: `timeout` around `gh issue comment` (default 8s); curl+token fallback (`HERMES_STATUS_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN` / `gh auth token`); OK/WARN log lines.

### Tip #157 (FALLBACK pin includes tip #156 DONE-post)

- [`hermes-dispatcher-downstream.sh`](shared-scripts/hermes-dispatcher-downstream.sh): default `HERMES_DOWNSTREAM_FALLBACK_REF` bumped `6c6881a` (#151) → **`ff0ccac`** (tip #156 OPERATOR restore / tip156 part-a on main).
- CDN fail on `main` must not assemble pre-#156 parts (silent `gh` status fail → Mac success without issue #1 Downstream DONE).
- Still includes tip #150/#151 inventory-integrity (SEED reject + DONE only when inventory present).

### Tip #158 (reject pre-#156/#150/#151 assembled parts)

- [`hermes-dispatcher-downstream.sh`](shared-scripts/hermes-dispatcher-downstream.sh): `_parts_integrity_ok` requires tip #156 DONE-post markers + tip #150/#151 inventory markers before assemble; stale co-located/CDN parts fall back to `ff0ccac`.
- Mac STALL / DOWNSTREAM-ONLY / ONE-SHOT: entrypoint integrity requires `_parts_integrity_ok`; legacy monolithic check requires `HERMES_GH_BEACON_TIMEOUT_SECS` (not bare `_post_github_status`).
- Closes: Mac could accept pre-#156 silent-fail status post when tip fetch "succeeded" with stale parts.

### Tip #159 (fail-closed if Downstream DONE GitHub beacon missing)

- [`hermes-dispatcher-part-a.sh`](shared-scripts/hermes-dispatcher-part-a.sh): `_post_github_status` returns non-zero on failure (was WARN-only).
- [`hermes-dispatcher-part-c.sh`](shared-scripts/hermes-dispatcher-part-c.sh): when inventory present, **exit 2** if issue #1 Downstream DONE beacon did not post (obj5/NAG were blind on silent WARN).
- Entrypoint `_parts_integrity_ok` requires tip #159 markers; Mac ONE-SHOT/STALL/ONLY pre-export `HERMES_STATUS_GITHUB_TOKEN` from `gh auth token`.
- FALLBACK bumped in tip #160 → `b2b5fc4`.

### Tip #160 (FALLBACK pin includes tip #159 fail-closed)

- [`hermes-dispatcher-downstream.sh`](shared-scripts/hermes-dispatcher-downstream.sh): default `HERMES_DOWNSTREAM_FALLBACK_REF` bumped `ff0ccac` → **`b2b5fc4`** (tip #159 fail-closed DONE beacon + tip #156/#158/#150/#151).
- CDN fail on `main` must not assemble pre-#159 parts (WARN-only status post → silent obj5 miss).

### Tip #161 (ENABLE git clone+push fallback for workflow install)

- [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](HERMES-ENABLE-DOWNSTREAM-ACTIONS.command) + ONE-SHOT Phase 2: when `gh api PUT` to `.github/workflows/downstream-stall.yml` fails (OAuth missing `workflow` scope → 404), fall back to shallow **git clone (SSH first) + commit + push** of `ci/downstream-stall.yml`.
- Closes: Mac ENABLE dead-ends on cloud/API-style tokens even when the operator's SSH git identity can push workflow files.
- Prefer Mac ONE-SHOT / STALL first; Path C Web UI paste remains last resort. Cloud Zapier/Github App still cannot write workflows.

### Tip #162 (STALL / DOWNSTREAM-ONLY tip-pin + fetch integrity)

- [`HERMES-DOWNSTREAM-RAL793-STALL.command`](HERMES-DOWNSTREAM-RAL793-STALL.command) + [`HERMES-DOWNSTREAM-ONLY.command`](HERMES-DOWNSTREAM-ONLY.command): tip banners were stale at #147/#148; now tip through **#162**.
- `_is_good_downstream` requires tip #160 FALLBACK (`b2b5fc4`) / tip #159 fail-closed markers so Mac STALL/ONLY cannot accept pre-#159 silent-WARN entrypoints.
- ONE-SHOT `_is_good_downstream` aligned.

### Tip #163 (ICS soft-hold tip-pin)

- Soft-hold / AuthURL tip ICS rewrite in [`hermes-join-part-b.sh`](shared-scripts/hermes-join-part-b.sh) now pins SUMMARY/DESCRIPTION/VALARM through **#163** (Mac ONE-SHOT + ENABLE git-push + FALLBACK `b2b5fc4`) instead of tip-less generic text.
- Prevents ICS soft-refresh from erasing tip #161/#162 operator guidance while AuthURL is held.

### Tip #164 (Mac launcher tip banners → #163+)

- [`HERMES-ONE-SHOT-UNBLOCK.command`](HERMES-ONE-SHOT-UNBLOCK.command), [`HERMES-DOWNSTREAM-RAL793-STALL.command`](HERMES-DOWNSTREAM-RAL793-STALL.command), [`HERMES-DOWNSTREAM-ONLY.command`](HERMES-DOWNSTREAM-ONLY.command), [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](HERMES-ENABLE-DOWNSTREAM-ACTIONS.command): tip banners were still **#162** after tip #163 ICS soft-hold shipped; now tip through **#164**.
- Re-download ONE-SHOT/STALL so Mac operators see tip #163 ICS soft-hold + tip #162 integrity in the banner.

### Tip #165 (ICS soft-hold tip-pin → #164+)

- Soft-hold ICS rewrite in [`hermes-join-part-b.sh`](shared-scripts/hermes-join-part-b.sh) was still pinning tip **#163** after tip #164 launcher banners shipped — soft-refresh would regress calendar SUMMARY/DESCRIPTION.
- Now pins tip through **#165** (launcher banners #164 + ENABLE/FALLBACK guidance).

### Tip #166 (ICS tip-stale soft-hold without DTEND remint)

- Soft-hold previously only rewrote ICS when `remain_s < 1800`, so local/calendar SUMMARY could stay stuck on an old tip (e.g. #162) for hours after tip #165 shipped.
- [`hermes-join-part-b.sh`](shared-scripts/hermes-join-part-b.sh): if SUMMARY tip pin is behind `HERMES_AUTHURL_ICS_EXPECTED_TIP` (default **166**), rewrite SUMMARY/DESCRIPTION/VALARM **in place** and preserve UID/DTEND/URL (no AuthURL remint).
- Soft-refresh templates + AuthURL suffix display use the **full** AuthURL id (no `[:12]` truncate).

### Tip #167 (ICS expected tip from TIP_PIN / CURRENT_AUTHURL.md)

- Tip-stale soft-hold (`HERMES_AUTHURL_ICS_EXPECTED_TIP`) no longer requires editing `hermes-join-part-b.sh` on every tip advance.
- Resolver order: env → [`TIP_PIN`](TIP_PIN) → parse `Tip through **#N**` from [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md) → default **167**.
- Soft-refresh ICS templates use the resolved tip number. Bump tip by updating `TIP_PIN` + `CURRENT_AUTHURL.md` (and launcher banners as needed).

### Tip #168 (CDN TIP_PIN hot-pick + standalone ICS soft-hold)

- Long-lived wait-login soft-holds can lag tip advances when local `TIP_PIN` is stale and join-part-b was sourced hours earlier.
- [`_resolve_ics_expected_tip`](shared-scripts/hermes-join-part-b.sh) now CDN-fetches [`TIP_PIN`](TIP_PIN) from `main` (max of local + CDN; env still wins) and optionally syncs local `TIP_PIN`.
- New [`shared-scripts/hermes-ics-soft-hold.sh`](shared-scripts/hermes-ics-soft-hold.sh): curl|bash-safe tip-stale/TTL soft-hold **without** reminting AuthURL or respawning wait-login.

### Tip #169 (wait-login soft-hold tick + Dropbox WAKE + Zapier GH reconnect)

- [`wait_for_running`](shared-scripts/hermes-join-part-c.sh) now runs [`hermes-ics-soft-hold.sh`](shared-scripts/hermes-ics-soft-hold.sh) about every 15m (`HERMES_ICS_SOFT_HOLD_EVERY_SECS`) while NeedsLogin — CDN TIP_PIN hot-pick without remint/respawn even when in-memory part-b is pre-tip168.
- Dropbox wake file: `/Hermes/WAKE-1d0d8050-tip169.txt` (AuthURL + ONE-SHOT).
- Path C Zapier `put_workflow_file_via_git_data` returned **Bad credentials** (task-limit cleared). Reconnect GitHub at `https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336` then retry, or Web UI / ENABLE tip #161.

### Tip #170 (Dropbox public WAKE link + Zapier Calendar reconnect note)

- Public Dropbox WAKE: `https://www.dropbox.com/scl/fi/t8p9b7qqnrrbrijhn1r1j/WAKE-1d0d8050-tip169.txt?rlkey=4p6zu480sotpw7lb34rjkbxli&dl=1`
- Zapier Google Calendar connection **stale** — reconnect `https://mcp.zapier.com/api/v1/connect-auth/GoogleCalendarCLIAPI?accountId=12547336&connectionId=55516487` (same class as GitHub Bad credentials for Path C).

### Tip #171 (ONE-SHOT opens Path C reconnect + Dropbox WAKE tabs)

- Mac [`HERMES-ONE-SHOT-UNBLOCK.command`](HERMES-ONE-SHOT-UNBLOCK.command) early-opens (parallel with STALL):
  - Dropbox public WAKE
  - Zapier GitHub reconnect (Path C `put_workflow_file_via_git_data` still **Bad credentials** even when Zapier reports `is_stale=false`)
  - Zapier Google Calendar reconnect (stale)
- Opt out: `HERMES_ONE_SHOT_OPEN_PATHC_RECONNECT=0`
- Closes: Mac session had to dig CURRENT_AUTHURL / OPERATOR for reconnect URLs; Path C stayed dead after tip#170 docs-only note.
- Cloud retry @ tip#171 still Bad credentials until operator reconnects GitHub at `https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336`.

### Tip #172 (NAG opens Path C reconnect tabs ≤1/30m)

- [`HERMES-INSTALL-DOWNSTREAM-NAG.command`](HERMES-INSTALL-DOWNSTREAM-NAG.command) / installed LaunchAgent now opens Dropbox WAKE + Zapier GH/Calendar reconnect while Downstream DONE missing.
- Throttled to ≤1/30m (`~/.hermes/nag-pathc-last.txt`) so 5-min nag ticks do not spam tabs.
- Opt out: `HERMES_NAG_OPEN_PATHC_RECONNECT=0`
- Closes: installed nag kept opening ONE-SHOT/Web UI/Tailscale but never surfaced Path C reconnect after tip#171 ONE-SHOT-only opens.
- Cloud Path C alts @ tip#172 still fail: Github MCP Contents API **404** on `.github/workflows/`; Zapier `put_file_from_repo` **Bad credentials**.
- Tip #169 soft-hold tick + Quo SMS remain the primary non-Gmail wakes while AuthURL holds.

### Tip #173 (Dropbox WAKE content refresh — same public link)

- Overwrote `/Hermes/WAKE-1d0d8050-tip169.txt` with tip **#173** wake text (AuthURL `1d0d8050` + ONE-SHOT + Path C Zapier reconnect URLs).
- Public link unchanged: `https://www.dropbox.com/scl/fi/t8p9b7qqnrrbrijhn1r1j/WAKE-1d0d8050-tip169.txt?rlkey=4p6zu480sotpw7lb34rjkbxli&dl=1`
- Path C cloud retry @ tip#173 still **Bad credentials** / workflow Contents **404**.

### Tip #174 (soft-hold marker + CURRENT ICS DTEND stamp)

- [`hermes-ics-soft-hold.sh`](shared-scripts/hermes-ics-soft-hold.sh) now writes `LAST_ICS_SOFT_HOLD.json` after every run (`ts`, `tip`, `url`, `dtend`, `rewrite=ttl|tip|none`).
- Stamps [`CURRENT_AUTHURL.md`](CURRENT_AUTHURL.md) with `**ICS hold (soft):** DTEND \`...\` (tip #N)` so agents/timers see the live hold window without parsing ICS.
- Tip-stale soft-hold still preserves UID/DTEND/URL; TTL rewrite still extends hold hours.
- Closes: soft-hold rewrites left CURRENT without a durable DTEND line; agents could not tell whether ICS was current after tip-pin bumps.
- Path C cloud still blocked until Zapier GitHub reconnect / Web UI workflow / Mac ENABLE tip#161.

### Tip #175 (ENABLE opens Web UI Path C tabs at START)

- [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](HERMES-ENABLE-DOWNSTREAM-ACTIONS.command) now opens create-workflow + Raw `ci/downstream-stall.yml` + Action secrets UI **before** gh/git install attempts.
- Cloud Path C still cannot write `.github/workflows/` (Github MCP Contents/trees **404**; Zapier `put_workflow_file_via_git_data` / `put_file_from_repo` **Bad credentials** even when `is_stale=false`).
- Opt out: `HERMES_ENABLE_OPEN_WEBUI_EARLY=0`
- Closes: standalone ENABLE waited through failed API+git before surfacing Web UI paste; operator had to dig fail-path URLs.
- Prefer Mac ONE-SHOT / STALL when Tailscale works; Web UI paste remains the cloud-token fallback for Path C.

### Tip #176 (NAG opens Raw paste + Action secrets with Path C throttle)

- [`HERMES-INSTALL-DOWNSTREAM-NAG.command`](HERMES-INSTALL-DOWNSTREAM-NAG.command) Path C ≤1/30m block now also opens Raw `ci/downstream-stall.yml` + Action secrets UI (create-workflow was already every 5m).
- Closes: NAG opened empty create-workflow editor without the Raw source tab; operator had to dig `ci/downstream-stall.yml` manually.
- Still throttled with Dropbox/Zapier reconnect (tip #172). Opt out: `HERMES_NAG_OPEN_PATHC_RECONNECT=0`
- Cloud Path C write still blocked (Github MCP 404 / Zapier Bad credentials).
