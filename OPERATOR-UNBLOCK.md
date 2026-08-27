# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-27T10:25Z

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
| **RAL-800** | `dae80aa2-e6d0-4225-9ae8-cdb72ccd8ec0` | **Done** — host-land only |
| **RAL-799** | `52e94e17-69e6-4688-a60e-aea25b090ebf` | Done |
| **RAL-820** | `0d76e06f-bf49-4587-a733-1b6f397f1392` | Done |

**Scripts on main (#27):** downstream + contract-install default `HERMES_RAL793_LINEAR_ISSUE_ID`; RAL-634 verify defaults `HERMES_RAL634_LINEAR_ISSUE_ID`.

**Prefer ticket identifiers in scripts** (`HERMES_RAL793_LINEAR_TICKET=RAL-793`) — scripts resolve via `issueSearch`. MCP agents must use UUIDs explicitly.

## Machine status inbox (GitHub)

[hermes-mac-land issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) receives machine posts when Mac/credentialed runs execute (land DIAG + downstream STARTED/DONE/FAILED). Cloud agents without SSH can watch this inbox for credentialed-run receipts.

## Live stall — RAL-793 run `2954673` (CLAIMED @ 23:25Z, silent ~10.9h+)

| Item | Status |
|------|--------|
| Run ID | `20260826T232521106484Z-2954673` |
| CLAIMED | **YES** @ 23:25:30Z via `hermes-now` / DISPATCH-NOW |
| Contract readback | **MISSING** |
| Inventory `evidence/RAL-793-inventory.md` | **MISSING** |
| RAL-634 verify PASS (downstream) | **NOT RUN** — live proof already Done separately |
| Ooterverse cloud SSH | **BLOCKED** (no secrets) |
| Latest downstream attempt | FAILED @ 01:04Z (`bc-3914e61d`, wrong env) |
| `## Downstream STARTED` / `DONE` | **NO** credentialed success yet |
| Operator wake | **Gmail ACTION** @ 10:05Z to `ilike4@gmail.com` (`HERMES-DOWNSTREAM-RAL793-STALL.command` attached; msg `1a042b03d5053dae`) |

### Fastest unblock (Mac Hermes, Tailscale up)

**Prefer:** open the Gmail ACTION attachment **or** download from GitHub (do **not** paste curl from Gmail body — prefer attachment / raw GitHub URL).

**Double-click:** `HERMES-DOWNSTREAM-RAL793-STALL.command` (pins run ID + stall recovery chain)

Or shell:

```bash
# Simplified post-#47 (auto-pins stall run + stack-apply=0 + stall_recovery=1):
HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Alternate — explicit run ID:
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
```

**Stall launcher defaults (#42 @ `21f49dc`):** `HERMES_AUTO_STACK_APPLY=0` (`.11` already at `6ce15a8` @ 03:30Z) + `HERMES_STALL_RECOVERY=1` (explicit Linear comment before re-dispatch).

**Stall dual DISPATCH-NOW (#52):** when `HERMES_STALL_RECOVERY=1`, Step 3 posts **two** `DISPATCH-NOW` passes (~90s apart). Host movement SLA is **300s** — a single interrupt on a 10h+ CLAIM may only fail the zombie as `claimed_without_executor_movement`; pass 2 reopens from FAILED under the pinned contract. Override wait via `HERMES_STALL_DISPATCH_WAIT_SECS`.

**Downstream chain:** inspect → contract install → (stack-apply skipped by default) → dual DISPATCH-NOW (stall) → RAL-634 verify.

Set `HERMES_AUTO_STACK_APPLY=1` only if `.11` mirror drifted from `main`.

## Program gates (2026-08-27)

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Linear interrupt (`hermes-now` / DISPATCH-NOW) | **DONE** — RAL-793 CLAIMED @ 23:25Z |
| 2 | GitHub→`.11` auto-apply + drift | **DONE** (RAL-799) |
| 3 | RAL-634 starvation / transition dedupe | **DONE** — moltbot #103 + live enter/suppress @ 03:35–03:45Z |
| 4 | Miss/idle alarms | **DONE** |
| 5 | RAL-793 canary + inventory | **OPEN** — sole program blocker |
| 6 | Operator docs | **Done** (#41 + #42 + #44 + #47–#50; #52 dual-dispatch) |

### Source follow-ups (recent)

| PR | Status |
|----|--------|
| moltbot [#103](https://github.com/ilike4movies/moltbot/pull/103) | **merged + live** @ `6ce15a8` — transition-aware watchdog dedupe |
| hermes-mac-land [#39](https://github.com/ilike4movies/hermes-mac-land/pull/39) | **merged** — verify gates on #103 artifacts |
| hermes-mac-land [#40](https://github.com/ilike4movies/hermes-mac-land/pull/40) | **merged** @ `0ba45ea` — downstream stack-apply step before verify |
| hermes-mac-land [#41](https://github.com/ilike4movies/hermes-mac-land/pull/41) | **merged** @ `1e492f3` — operator doc sync for #40 chain |
| hermes-mac-land [#42](https://github.com/ilike4movies/hermes-mac-land/pull/42) | **merged** @ `21f49dc` — stall launcher skip stack-apply + recovery mode |
| hermes-mac-land [#36](https://github.com/ilike4movies/hermes-mac-land/pull/36) | **merged** — cloud boot auto-pins stall run when `HERMES_AUTO_SURGICAL_LAND=0` |
| hermes-mac-land [#44](https://github.com/ilike4movies/hermes-mac-land/pull/44) | **merged** @ `8fcac2a` — cloud boot stall defaults (`HERMES_AUTO_STACK_APPLY=0`, `HERMES_STALL_RECOVERY=1`) |
| hermes-mac-land [#47](https://github.com/ilike4movies/hermes-mac-land/pull/47) | **merged** @ `858cb6a` — bare curl stall auto-defaults (#42/#44 parity in downstream.sh) |
| hermes-mac-land [#48](https://github.com/ilike4movies/hermes-mac-land/pull/48) | **merged** @ `f3c7578` — OPERATOR sync for #47 |
| hermes-mac-land [#49](https://github.com/ilike4movies/hermes-mac-land/pull/49) | **merged** @ `964943d` — README post-#47 one-liner |
| hermes-mac-land [#50](https://github.com/ilike4movies/hermes-mac-land/pull/50) | **merged** @ `dc89811` — skip GitHub beacon on expected preflight fail |
| hermes-mac-land [#52](https://github.com/ilike4movies/hermes-mac-land/pull/52) | **merged** @ `c064314` — dual DISPATCH-NOW for SLA-stale CLAIM stall recovery |
| hermes-mac-land `60cf813` | **on main** — downstream fail-fast preflight without `COMPOSER_REPO_URL` |

### Critical path (remaining)

1. ~~Interrupt + apply gates~~ **DONE** (RAL-820, RAL-800, RAL-799)
2. ~~RAL-634 live prove-out~~ **DONE** (natural watchdog + transition dedupe)
3. **Credentialed downstream** → contract readback on RAL-793 → inventory evidence
4. RAL-794 handoff comment (blocked on #3)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **Done** @ 20:21Z |
| RAL-799 live prove-out | **Done** @ 20:22Z — canary+drift verified |
| RAL-634 starvation alarm | **Done** — degraded + transition dedupe live |
| Operator scripts on main | **Done** (#40 stack-apply; #42 stall recovery; #52 dual-dispatch on main) |
| PR attachments detached from RAL-793 | **Done** |
| RAL-793 contract pinned | **OPEN** — run credentialed script |
| RAL-793 inventory evidence | **OPEN** — run `2954673` stalled |

## Credentialed run commands (Mac / cloud agent with SSH secrets)

### Mac double-click (recommended when RAL-800/799 already Done)

- **`HERMES-DOWNSTREAM-RAL793-STALL.command`** — pins stalled run `2954673`; defaults skip stack-apply + stall recovery (#42); dual DISPATCH-NOW when #52 on tip
- **`HERMES-DOWNSTREAM-ONLY.command`** — contract install + stack-apply + auto DISPATCH-NOW + RAL-634 verify (no land)
- **`HERMES-DIAGNOSE-THEN-LAND.command`** — full diagnose + land (when tip refresh needed)

### Shell one-liners

```bash
# Stalled run (inspect + downstream; recommended now):
# Simplified post-#47 (auto-pins stall run + stack-apply=0 + stall_recovery=1):
HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Alternate — explicit run ID:
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Full chain: land + verify + contract install + RAL-634 verify
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash

# Or downstream-only (if land already done; auto DISPATCH-NOW default):
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Or individually:
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh | bash -s -- --post-linear
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-moltbot-stack-apply-via-ssh.sh | bash -s -- --post-linear
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh | bash -s -- --post-linear
```

Set `HERMES_SKIP_DOWNSTREAM=1` on resume-land for land-only smoke. Set `HERMES_AUTO_DISPATCH_RAL793=0` to skip auto DISPATCH-NOW. Set `HERMES_AUTO_STACK_APPLY=0` to skip governed stack-apply (stall launcher default since #42).

### hermes-mac-land cloud agent (env LEGACY Hermes .11)

On boot with secrets, `hermes-cloud-agent-start.sh` chains downstream gates by default (`HERMES_AUTO_DOWNSTREAM=1`). Set `HERMES_AUTO_SURGICAL_LAND=0` for downstream-only boot.

Since **#36** (2026-08-27): when `HERMES_AUTO_SURGICAL_LAND=0` and `HERMES_RUN_ID` is unset, boot auto-pins stall run `20260826T232521106484Z-2954673` (override via `HERMES_RUN_ID` or `HERMES_DEFAULT_STALL_RUN_ID`).

Minimum boot env after #36:

```bash
HERMES_AUTO_SURGICAL_LAND=0
# HERMES_RUN_ID optional — defaults to stalled canary run
```

Since **#44** (2026-08-27): when downstream-only boot pins stall run `2954673`, also defaults `HERMES_AUTO_STACK_APPLY=0` and `HERMES_STALL_RECOVERY=1` (parity with stall launcher #42).

Since **#47** (2026-08-27): `hermes-dispatcher-downstream.sh` itself applies the same stall defaults when run ID matches `2954673` or is auto-pinned via `HERMES_AUTO_SURGICAL_LAND=0`.

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

**Success receipts:** GitHub #1 `## Downstream STARTED` → `## Downstream DONE`; RAL-793 contract readback; `evidence/RAL-793-inventory.md` on `.11`.

## RAL-793 stall inspect (CLAIMED but silent on Linear)

When RAL-793 shows **CLAIMED** but no inventory / WORK-PACKET-DONE / handoff after ~30m, inspect the live run dir on `.11` (read-only):

```bash
# Default: current-ticket run or latest run dir
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-run-inspect.sh | bash -s -- --post-linear

# Pin a specific run (e.g. interrupt canary):
HERMES_RUN_ID=20260826T232521106484Z-2954673 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-run-inspect.sh | bash -s -- --post-linear
```

Posts artifact summary to RAL-793. Downstream chain auto-runs inspect when `HERMES_RUN_ID` is set (#34). Stall recovery mode (#42) posts explicit Linear comment before re-dispatch; #52 adds dual DISPATCH-NOW for SLA-stale CLAIMs.

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DOWNSTREAM-RAL793-STALL.command` / `HERMES-DOWNSTREAM-ONLY.command` / `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent on **hermes-mac-land** (not Ooterverse) with env LEGACY Hermes .11 — **must start from web UI**, not Ooterverse subagent spawn

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
