# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-28T00:20Z

## ⚠️ Linear auto-Done hygiene

**Do NOT attach GitHub PRs to RAL-793, RAL-798, RAL-799, or RAL-634** while canaries are open — Linear auto-Dones on PR merge and falsely closes tickets before `.11` prove-out.

**Also:** do **not** put `RAL-793` (or other open canary IDs) in **PR titles** — GitHub auto-links on merge even when you do not attach manually.

| Incident | Cause | Fix |
|----------|-------|-----|
| 20:48Z | #18 merged + attached | Reverted; attachment detached @ 21:02Z |
| 21:29Z | #20 title contained `RAL-793` → auto-attach | Reverted @ 21:30Z; attachment detached |
| 21:38Z | MCP comment used wrong issue UUID → posted on RAL-800 | Corrected @ 21:40Z; see UUID table below |
| 01:04Z | Cloud subagent `bc-3914e61d` booted on **Ooterverse** (not hermes-mac-land) | Downstream FAILED pre-SSH; use Mac or web-UI LEGACY `.11` agent |
| 03:49Z | #40 auto-attached to RAL-634 (Done) | Detach if needed; do not re-open RAL-634 for doc-only merges |
| 04:22Z | Cloud subagent `bc-cf21d38f` spawned from Ooterverse | Skipped downstream to avoid FAILED spam; use Mac or web-UI `hermes-mac-land` + LEGACY `.11` |
| 23:45Z | OPERATOR UUID table had RAL-799/RAL-820 swapped; RAL-798 missing | Corrected: RAL-798=`52e94e17…`, RAL-799=`0d76e06f…`, RAL-820=`144b087c…` |

## ⚠️ Ooterverse cloud agents cannot run downstream

**Do not spawn Hermes subagents from Ooterverse-Saturns-Quest** — they inherit the wrong repo/env and cannot receive `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` at boot.

`hermes-dispatcher-downstream.sh` **fail-fast preflights** (since `60cf813` @ 04:12Z): missing `TS_AUTHKEY`/`HERMES_HOST_SSH_PRIVATE_KEY` fails in <1s even when `COMPOSER_REPO_URL` unset; Ooterverse repo also → `FAIL preflight: wrong_repo`.

**Only these paths work for live gates:**
1. **Mac Hermes** — double-click `HERMES-DOWNSTREAM-RAL793-STALL.command`
2. **Web UI cloud agent** — repo `ilike4movies/hermes-mac-land`, env **LEGACY Hermes .11**, secrets at boot

## Linear issue UUIDs (MCP / API comment posting)

When posting via Linear MCP `save_comment`, **verify `issueId` UUID** — do not guess from subscriptions.

| Ticket | UUID | Status |
|--------|------|--------|
| **RAL-793** | `963472c8-cc84-426a-9ed6-79e08566353a` | In Progress — canary open |
| **RAL-634** | `1b5a7e86-1d14-456f-b0d1-39a02df243c2` | **Done** — live #103 transition dedupe proof @ 03:35–03:45Z |
| **RAL-798** | `52e94e17-69e6-4688-a60e-aea25b090ebf` | In Progress — WIP-park **#110 MERGED** `main` @ `a535cb7` / tip `c753da8a`; `.11` apply + runtime canary still required |
| **RAL-799** | `0d76e06f-bf49-4587-a733-1b6f397f1392` | **Done** — GitHub→host apply + drift |
| **RAL-800** | `dae80aa2-e6d0-4225-9ae8-cdb72ccd8ec0` | **Done** — host-land only |
| **RAL-820** | `144b087c-79f2-4a31-aa21-a98357547843` | **Done** — interrupt→executor canary |

**Scripts on main (#27):** downstream + contract-install default `HERMES_RAL793_LINEAR_ISSUE_ID`; RAL-634 verify defaults `HERMES_RAL634_LINEAR_ISSUE_ID`.

**Prefer ticket identifiers in scripts** (`HERMES_RAL793_LINEAR_TICKET=RAL-793`) — scripts resolve via `issueSearch`. MCP agents must use UUIDs explicitly.

## Machine status inbox (GitHub)

[hermes-mac-land issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) receives machine posts when Mac/credentialed runs execute (land DIAG + downstream STARTED/DONE/FAILED). Cloud agents without SSH can watch this inbox for credentialed-run receipts.

## Live stall — RAL-793 run `2954673` (CLAIMED @ 23:25Z 2026-08-26, silent ~24.7h+)

| Item | Status |
|------|--------|
| Run ID | `20260826T232521106484Z-2954673` |
| CLAIMED | **YES** @ 23:25:30Z via `hermes-now` / DISPATCH-NOW |
| Contract readback | **MISSING** |
| Inventory `evidence/RAL-793-inventory.md` | **MISSING** |
| RAL-634 verify PASS (downstream) | **NOT RUN** — live proof already Done separately |
| Ooterverse cloud SSH | **BLOCKED** (no secrets) |
| Latest downstream attempt | FAILED @ 01:04Z (`bc-3914e61d`, wrong env) |
| `## Downstream STARTED` / `DONE` | **NO** credentialed success yet (0 real beacons) |
| Operator wake | **Gmail ACTION** `1a042b03d5053dae` + **URGENT** `1a0458a5cef8d952` (bumped `1a045b2857ed4631` @ 00:15Z) — still UNREAD; attachment `HERMES-DOWNSTREAM-RAL793-STALL.command` |

### Fastest unblock (Mac Hermes, Tailscale up)

**Prefer:** open the Gmail ACTION attachment **or** download from GitHub (do **not** paste curl from Gmail body — prefer attachment / raw GitHub URL).

**Double-click:** `HERMES-DOWNSTREAM-RAL793-STALL.command` (pins run ID + stall recovery + stack-apply for #110)

Or shell:

```bash
# Post-#54 (auto-pins stall run + stack-apply=1 + stall_recovery=1):
HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Alternate — explicit run ID:
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
```

**Stall launcher defaults (#54 @ `54319b6`):** `HERMES_AUTO_STACK_APPLY=1` (lands moltbot #110 WIP-park on `.11`) + `HERMES_STALL_RECOVERY=1` (explicit Linear comment before re-dispatch). Override `HERMES_AUTO_STACK_APPLY=0` only after host tip confirms `c753da8a` / `a535cb7`.

**Stall dual DISPATCH-NOW (#52):** when `HERMES_STALL_RECOVERY=1`, Step 3 posts **two** `DISPATCH-NOW` passes (~90s apart). Host movement SLA is **300s** — a single interrupt on a 10h+ CLAIM may only fail the zombie as `claimed_without_executor_movement`; pass 2 reopens from FAILED under the pinned contract. Override wait via `HERMES_STALL_DISPATCH_WAIT_SECS`.

**Downstream chain:** inspect → contract install → **stack-apply** (default ON for stall) → dual DISPATCH-NOW (stall) → RAL-634 verify.

## Program gates (2026-08-28)

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Linear interrupt (`hermes-now` / DISPATCH-NOW) | **DONE** — RAL-793 CLAIMED @ 23:25Z |
| 2 | GitHub→`.11` auto-apply + drift | **DONE** (RAL-799) |
| 3 | RAL-634 starvation / transition dedupe | **DONE** — moltbot #103 + live enter/suppress @ 03:35–03:45Z |
| 4 | Miss/idle alarms | **DONE** |
| 5 | RAL-793 canary + inventory | **OPEN** — sole program blocker (~24.7h+ silent CLAIM) |
| 6 | Operator docs | **Sync** — #53 UUID/24h+#110 note; #54 stall stack-apply=1 |

### Source follow-ups (recent)

| PR | Status |
|----|--------|
| moltbot [#110](https://github.com/ilike4movies/moltbot/pull/110) | **MERGED** @ `a535cb7` (tip `c753da8a`) — WIP-park material-evidence; **`.11` apply pending** |
| hermes-mac-land [#54](https://github.com/ilike4movies/hermes-mac-land/pull/54) | **merged** @ `54319b6` — stall defaults `HERMES_AUTO_STACK_APPLY=1` (land #110 + recover RAL-793) |
| hermes-mac-land [#53](https://github.com/ilike4movies/hermes-mac-land/pull/53) | **merged** @ `d512666` — stall ~24h+; UUID table fix; #110 merge note |
| moltbot [#103](https://github.com/ilike4movies/moltbot/pull/103) | **merged + live** @ `6ce15a8` — transition-aware watchdog dedupe |
| hermes-mac-land [#52](https://github.com/ilike4movies/hermes-mac-land/pull/52) | **merged** @ `c064314` — dual DISPATCH-NOW for SLA-stale CLAIM stall recovery |
| hermes-mac-land [#50](https://github.com/ilike4movies/hermes-mac-land/pull/50) | **merged** @ `dc89811` — skip GitHub beacon on expected preflight fail |
| hermes-mac-land [#47](https://github.com/ilike4movies/hermes-mac-land/pull/47) | **merged** @ `858cb6a` — bare curl stall auto-defaults |
| hermes-mac-land [#44](https://github.com/ilike4movies/hermes-mac-land/pull/44) | **merged** @ `8fcac2a` — cloud boot stall defaults (superseded stack-apply default by #54) |
| hermes-mac-land [#42](https://github.com/ilike4movies/hermes-mac-land/pull/42) | **merged** @ `21f49dc` — stall launcher recovery mode |
| hermes-mac-land [#40](https://github.com/ilike4movies/hermes-mac-land/pull/40) | **merged** @ `0ba45ea` — downstream stack-apply step before verify |
| hermes-mac-land [#36](https://github.com/ilike4movies/hermes-mac-land/pull/36) | **merged** — cloud boot auto-pins stall run when `HERMES_AUTO_SURGICAL_LAND=0` |
| hermes-mac-land `60cf813` | **on main** — downstream fail-fast preflight without `COMPOSER_REPO_URL` |

### Critical path (remaining)

1. ~~Interrupt + apply gates~~ **DONE** (RAL-820, RAL-800, RAL-799)
2. ~~RAL-634 live prove-out~~ **DONE** (natural watchdog + transition dedupe)
3. **Credentialed downstream** → contract readback on RAL-793 → inventory evidence
4. RAL-794 handoff comment (blocked on #3)
5. **WIP-park #110 on `.11`** — STALL.command now defaults stack-apply ON (#54); confirm tip `c753da8a` / `a535cb7` + runtime canary; keep RAL-798 In Progress until then

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **Done** @ 20:21Z |
| RAL-799 live prove-out | **Done** @ 20:22Z — canary+drift verified |
| RAL-634 starvation alarm | **Done** — degraded + transition dedupe live |
| Operator scripts on main | **Done** (#40 stack-apply; #52 dual-dispatch; **#54 stall stack-apply=1**) |
| PR attachments detached from RAL-793 | **Done** |
| RAL-793 contract pinned | **OPEN** — run credentialed script |
| RAL-793 inventory evidence | **OPEN** — run `2954673` stalled |
| moltbot #110 on GitHub main | **MERGED** @ `a535cb7` / tip `c753da8a` |
| moltbot #110 on `/opt/moltbot` | **OPEN** — await auto-apply or #54 STALL stack-apply readback |

## Credentialed run commands (Mac / cloud agent with SSH secrets)

### Mac double-click (recommended when RAL-800/799 already Done)

- **`HERMES-DOWNSTREAM-RAL793-STALL.command`** — pins stalled run `2954673`; defaults **stack-apply=1** (#54) + stall recovery + dual DISPATCH-NOW (#52)
- **`HERMES-DOWNSTREAM-ONLY.command`** — contract install + stack-apply + auto DISPATCH-NOW + RAL-634 verify (no land)
- **`HERMES-DIAGNOSE-THEN-LAND.command`** — full diagnose + land (when tip refresh needed)

### Shell one-liners

```bash
# Stalled run (inspect + stack-apply #110 + dual DISPATCH-NOW):
HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Alternate — explicit run ID:
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Full chain: land + verify + contract install + RAL-634 verify
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash

# Or individually:
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh | bash -s -- --post-linear
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh | bash -s -- --post-linear
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh | bash -s -- --post-linear
```

Set `HERMES_SKIP_DOWNSTREAM=1` on resume-land for land-only smoke. Set `HERMES_AUTO_DISPATCH_RAL793=0` to skip auto DISPATCH-NOW. Set `HERMES_AUTO_STACK_APPLY=0` to skip governed stack-apply **only after** `/opt/moltbot` confirms tip `c753da8a` / `a535cb7`.

### hermes-mac-land cloud agent (env LEGACY Hermes .11)

On boot with secrets, `hermes-cloud-agent-start.sh` chains downstream gates by default (`HERMES_AUTO_DOWNSTREAM=1`). Set `HERMES_AUTO_SURGICAL_LAND=0` for downstream-only boot.

Since **#36** (2026-08-27): when `HERMES_AUTO_SURGICAL_LAND=0` and `HERMES_RUN_ID` is unset, boot auto-pins stall run `20260826T232521106484Z-2954673` (override via `HERMES_RUN_ID` or `HERMES_DEFAULT_STALL_RUN_ID`).

Minimum boot env after #36:

```bash
HERMES_AUTO_SURGICAL_LAND=0
# HERMES_RUN_ID optional — defaults to stalled canary run
```

Since **#54** (merged @ `54319b6`): stall-run defaults `HERMES_AUTO_STACK_APPLY=1` + `HERMES_STALL_RECOVERY=1` (STALL.command, downstream.sh, cloud-start) so one click lands #110 and recovers RAL-793.

Since **#52** (merged @ `c064314`): stall recovery posts **two** `DISPATCH-NOW` passes (~90s) so SLA-stale CLAIMs reopen after fail.

## Troubleshooting downstream FAIL (SSH / wrong environment)

If `hermes-dispatcher-downstream.sh` exits at Step 1 with `FAIL SSH to .11` and **no** `DISPATCH-NOW` is posted, that is **correct fail-closed behavior** — do not post `DISPATCH-NOW` manually.

| Symptom | Likely cause |
|---------|--------------|
| `FAIL preflight: wrong_repo=Ooterverse` | Agent on wrong repo/env — fails in <1s (since `896251d`) |
| `SKIP GitHub beacon (preflight expected on wrong env)` | Ooterverse/missing secrets — no `## Downstream FAILED` posted (since #50) |
| `FAIL preflight: missing_secrets=TS_AUTHKEY+HERMES_HOST_SSH_PRIVATE_KEY` | Cloud agent without Runtime Secrets at boot |
| `ssh: connect to host 100.105.194.96 port 22: Connection timed out` | Missing `TS_AUTHKEY` (no Tailscale mesh) or wrong cloud environment |
| `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` unset | Agent booted on **Ooterverse** env instead of **LEGACY Hermes .11** |
| Log: `FAIL: contract install failed — not dispatching` | SSH preflight failed (exit 10); steps 2–4 never run |
| Log: `FAIL: stack-apply failed` | SSH ok but governed apply failed — check moltbot mirror on `.11` |
| No `## Downstream STARTED` on GitHub #1 | Run never reached host; or `gh` token missing on Mac |

**Fix (pick one):**

1. **Mac Hermes** (Tailscale up): double-click `HERMES-DOWNSTREAM-RAL793-STALL.command` or run stall one-liner above
2. **New cloud agent** on repo `ilike4movies/hermes-mac-land` with environment **LEGACY Hermes .11 — do not use for Ooterverse**
3. **Add secrets** `TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` to the agent environment at boot (not mid-session)

**Success receipts:** GitHub #1 `## Downstream STARTED` → `## Downstream DONE`; RAL-793 contract readback; `evidence/RAL-793-inventory.md` on `.11`; `/opt/moltbot` tip includes #110 (`c753da8a`).

## RAL-793 stall inspect (CLAIMED but silent on Linear)

When RAL-793 shows **CLAIMED** but no inventory / WORK-PACKET-DONE / handoff after ~30m, inspect the live run dir on `.11` (read-only):

```bash
# Default: current-ticket run or latest run dir
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-run-inspect.sh | bash -s -- --post-linear

# Pin a specific run (e.g. interrupt canary):
HERMES_RUN_ID=20260826T232521106484Z-2954673 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-run-inspect.sh | bash -s -- --post-linear
```

Posts artifact summary to RAL-793. Downstream chain auto-runs inspect when `HERMES_RUN_ID` is set (#34). Stall recovery mode posts explicit Linear comment before re-dispatch; #52 adds dual DISPATCH-NOW for SLA-stale CLAIMs.

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DOWNSTREAM-RAL793-STALL.command` / `HERMES-DOWNSTREAM-ONLY.command` / `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent on **hermes-mac-land** (not Ooterverse) with env LEGACY Hermes .11 — **must start from web UI**, not Ooterverse subagent spawn

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
