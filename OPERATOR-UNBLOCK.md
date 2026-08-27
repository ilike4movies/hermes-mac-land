# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-27T00:53Z

## ⚠️ Linear auto-Done hygiene

**Do NOT attach GitHub PRs to RAL-793, RAL-798, RAL-799, or RAL-634** while canaries are open — Linear auto-Dones on PR merge and falsely closes tickets before `.11` prove-out.

**Also:** do **not** put `RAL-793` (or other open canary IDs) in **PR titles** — GitHub auto-links on merge even when you do not attach manually.

| Incident | Cause | Fix |
|----------|-------|-----|
| 20:48Z | #18 merged + attached | Reverted; attachment detached @ 21:02Z |
| 21:29Z | #20 title contained `RAL-793` → auto-attach | Reverted @ 21:30Z; attachment detached |
| 21:38Z | MCP comment used wrong issue UUID → posted on RAL-800 | Corrected @ 21:40Z; see UUID table below |

## Linear issue UUIDs (MCP / API comment posting)

When posting via Linear MCP `save_comment`, **verify `issueId` UUID** — do not guess from subscriptions.

| Ticket | UUID | Status |
|--------|------|--------|
| **RAL-793** | `963472c8-cc84-426a-9ed6-79e08566353a` | In Progress — canary open |
| **RAL-634** | `1b5a7e86-1d14-456f-b0d1-39a02df243c2` | Todo — live prove-out pending |
| **RAL-800** | `dae80aa2-e6d0-4225-9ae8-cdb72ccd8ec0` | **Done** — host-land only |
| **RAL-799** | `52e94e17-69e6-4688-a60e-aea25b090ebf` | Done |
| **RAL-820** | `0d76e06f-bf49-4587-a733-1b6f397f1392` | Done |

**Scripts on main (#27):** downstream + contract-install default `HERMES_RAL793_LINEAR_ISSUE_ID`; RAL-634 verify defaults `HERMES_RAL634_LINEAR_ISSUE_ID`.

**Prefer ticket identifiers in scripts** (`HERMES_RAL793_LINEAR_TICKET=RAL-793`) — scripts resolve via `issueSearch`. MCP agents must use UUIDs explicitly.

## Machine status inbox (GitHub)

[hermes-mac-land issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) receives machine posts when Mac/credentialed runs execute (land DIAG + downstream STARTED/DONE/FAILED). Cloud agents without SSH can watch this inbox for credentialed-run receipts.

## Live stall — RAL-793 run `2954673` (CLAIMED @ 23:25Z, silent ~90m+)

| Item | Status |
|------|--------|
| Run ID | `20260826T232521106484Z-2954673` |
| CLAIMED | **YES** @ 23:25:30Z via `hermes-now` / DISPATCH-NOW |
| Contract readback | **MISSING** |
| Inventory `evidence/RAL-793-inventory.md` | **MISSING** |
| RAL-634 verify PASS | **NOT RUN** |
| Ooterverse cloud SSH | **BLOCKED** (no secrets) |

### Fastest unblock (Mac Hermes, Tailscale up)

**Double-click:** `HERMES-DOWNSTREAM-RAL793-STALL.command` (pins run ID + inspect + downstream chain)

Or shell:

```bash
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
```

Chain: inspect → contract install → DISPATCH-NOW → RAL-634 verify.

## Live now — RAL-820 Done; #121/#122 installed

| Item | Evidence |
|------|----------|
| Canary | Run `1097131`, `req-c8a22ccbc2504e6b`, `VERIFIED_COMPLETE`, **0** model/API/tool calls |
| Replay | `1099734` = `healthy_noop` |
| Comment discovery | [#122](https://github.com/ilike4movies/hermes-agent-cos/pull/122) **merged + live** (`comments(last:N)` V2, dispatcher `54cccf31…`) |
| Natural cycle | `1131057` / dispatcher `1131978` = `healthy_noop` |
| Timer | Active (5m) |
| RAL-820 | **Done** |

### Source follow-ups

| PR | Status |
|----|--------|
| [#121](https://github.com/ilike4movies/hermes-agent-cos/pull/121) | **merged + live** — preserve 0755 modes on apply |
| [#122](https://github.com/ilike4movies/hermes-agent-cos/pull/122) | **merged + live** — newest-comment DISPATCH-NOW discovery |
| [#123](https://github.com/ilike4movies/hermes-agent-cos/pull/123) | **closed** — superseded by #122 |
| [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) | **merged** — direction binding for recovery ledger |
| [#125](https://github.com/ilike4movies/hermes-agent-cos/pull/125) | **merged** — RAL-793 inventory contract stager |
| [#141](https://github.com/ilike4movies/hermes-agent-cos/pull/141) | **merged** — movement-SLA wallclock to cos-local |
| moltbot [#76](https://github.com/ilike4movies/moltbot/pull/76)–[#79](https://github.com/ilike4movies/moltbot/pull/79) | **merged + live** on `.11` @ 20:21Z |
| hermes-mac-land [#18](https://github.com/ilike4movies/hermes-mac-land/pull/18) | **merged** — verify + contract install + starvation prove-out scripts |
| hermes-mac-land [#19](https://github.com/ilike4movies/hermes-mac-land/pull/19) | **merged** — downstream auto-chain + Mac launcher |
| hermes-mac-land [#20](https://github.com/ilike4movies/hermes-mac-land/pull/20) | **merged** — auto DISPATCH-NOW after contract install (do not link to RAL-793) |
| hermes-mac-land [#24](https://github.com/ilike4movies/hermes-mac-land/pull/24) | **merged** — cloud-agent-start log sync with auto-dispatch |
| hermes-mac-land [#25](https://github.com/ilike4movies/hermes-mac-land/pull/25) | **merged** — Linear UUID cheat sheet for MCP posting |
| hermes-mac-land [#26](https://github.com/ilike4movies/hermes-mac-land/pull/26) | **merged** — starvation verify latest-run + fail-closed proof |
| hermes-mac-land [#27](https://github.com/ilike4movies/hermes-mac-land/pull/27) | **merged** — downstream + contract-install pin HERMES_RAL793_LINEAR_ISSUE_ID |
| hermes-mac-land [#28](https://github.com/ilike4movies/hermes-mac-land/pull/28) | **merged** — OPERATOR-UNBLOCK sync #25–#27 |
| hermes-mac-land [#29](https://github.com/ilike4movies/hermes-mac-land/pull/29) | **merged** — README downstream-only critical path |
| hermes-mac-land [#30](https://github.com/ilike4movies/hermes-mac-land/pull/30) | **merged** — downstream GitHub status beacon on issue #1 |
| hermes-mac-land [#31](https://github.com/ilike4movies/hermes-mac-land/pull/31) | **merged** — downstream launcher pins GitHub beacon script |
| hermes-mac-land [#33](https://github.com/ilike4movies/hermes-mac-land/pull/33) | **merged** — `hermes-ral793-run-inspect.sh` + stall runbook |
| hermes-mac-land [#34](https://github.com/ilike4movies/hermes-mac-land/pull/34) | **merged** — downstream Step 0 auto-inspect when `HERMES_RUN_ID` set |
| hermes-mac-land [#35](https://github.com/ilike4movies/hermes-mac-land/pull/35) | **closed/superseded** — stall launcher landed direct to main |
| hermes-mac-land [#36](https://github.com/ilike4movies/hermes-mac-land/pull/36) | **merged** — cloud boot auto-pins stall run when `HERMES_AUTO_SURGICAL_LAND=0` |

### Critical path (remaining)

1. ~~Interrupt + apply gates~~ **DONE** (RAL-820, RAL-800, RAL-799)
2. **Credentialed run** → contract readback on RAL-793 → auto `DISPATCH-NOW` (downstream script)
3. Prove inventory evidence on RAL-793 (not WORK-PACKET-DONE alone)
4. RAL-634 starvation verify result on RAL-634 (posted by downstream script)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **Done** @ 20:21Z |
| RAL-799 live prove-out | **Done** @ 20:22Z — canary+drift verified |
| Local cloud-apply watch (#79) | **installed** @ 19:14Z surgical-apply |
| Operator scripts on main | **Done** |
| PR attachments detached from RAL-793 | **Done** (#18 @ 21:02Z, #20 @ 21:30Z) |
| RAL-793 contract pinned | **OPEN** — run credentialed script |
| RAL-793 inventory evidence | **OPEN** — run `2954673` stalled |
| RAL-634 starvation alarm | **OPEN** — live prove-out pending |

## Credentialed run commands (Mac / cloud agent with SSH secrets)

### Mac double-click (recommended when RAL-800/799 already Done)

- **`HERMES-DOWNSTREAM-RAL793-STALL.command`** — pins stalled run `2954673` + inspect + downstream (use now)
- **`HERMES-DOWNSTREAM-ONLY.command`** — contract install + auto DISPATCH-NOW + RAL-634 verify (no land)
- **`HERMES-DIAGNOSE-THEN-LAND.command`** — full diagnose + land (when tip refresh needed)

### Shell one-liners

```bash
# Stalled run (inspect + downstream; recommended now):
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Full chain: land + verify + contract install + RAL-634 verify
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash

# Or downstream-only (if land already done; auto DISPATCH-NOW default):
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Or individually:
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh | bash -s -- --post-linear
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh | bash -s -- --post-linear
```

Set `HERMES_SKIP_DOWNSTREAM=1` on resume-land for land-only smoke. Set `HERMES_AUTO_DISPATCH_RAL793=0` to skip auto DISPATCH-NOW.

### hermes-mac-land cloud agent (env LEGACY Hermes .11)

On boot with secrets, `hermes-cloud-agent-start.sh` chains downstream gates by default (`HERMES_AUTO_DOWNSTREAM=1`). Set `HERMES_AUTO_SURGICAL_LAND=0` for downstream-only boot.

Since **#36** (2026-08-27): when `HERMES_AUTO_SURGICAL_LAND=0` and `HERMES_RUN_ID` is unset, boot auto-pins stall run `20260826T232521106484Z-2954673` (override via `HERMES_RUN_ID` or `HERMES_DEFAULT_STALL_RUN_ID`).

Minimum boot env after #36:

```bash
HERMES_AUTO_SURGICAL_LAND=0
# HERMES_RUN_ID optional — defaults to stalled canary run
```

## Troubleshooting downstream FAIL (SSH / wrong environment)

If `hermes-dispatcher-downstream.sh` exits at Step 1 with `FAIL SSH to .11` and **no** `DISPATCH-NOW` is posted, that is **correct fail-closed behavior** — do not post `DISPATCH-NOW` manually.

| Symptom | Likely cause |
|---------|--------------|
| `ssh: connect to host 100.105.194.96 port 22: Connection timed out` | Missing `TS_AUTHKEY` (no Tailscale mesh) or wrong cloud environment |
| `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` unset | Agent booted on **Ooterverse** env instead of **LEGACY Hermes .11** |
| Log: `FAIL: contract install failed — not dispatching` | SSH preflight failed (exit 10); steps 2–3 never run |
| No `## Downstream STARTED` on GitHub #1 | Run never reached host; or `gh` token missing on Mac |

**Fix (pick one):**

1. **Mac Hermes** (Tailscale up): double-click `HERMES-DOWNSTREAM-RAL793-STALL.command` or run stall one-liner above
2. **New cloud agent** on repo `ilike4movies/hermes-mac-land` with environment **LEGACY Hermes .11 — do not use for Ooterverse**
3. **Add secrets** `TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` to the agent environment

**Success receipts:** GitHub #1 `## Downstream STARTED` → `## Downstream DONE`; RAL-793 contract readback; RAL-634 verify PASS; `evidence/RAL-793-inventory.md` on `.11`.

## RAL-793 stall inspect (CLAIMED but silent on Linear)

When RAL-793 shows **CLAIMED** but no inventory / WORK-PACKET-DONE / handoff after ~30m, inspect the live run dir on `.11` (read-only):

```bash
# Default: current-ticket run or latest run dir
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-run-inspect.sh | bash -s -- --post-linear

# Pin a specific run (e.g. interrupt canary):
HERMES_RUN_ID=20260826T232521106484Z-2954673 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-run-inspect.sh | bash -s -- --post-linear
```

Posts artifact summary to RAL-793. Downstream chain auto-runs inspect when `HERMES_RUN_ID` is set (#34).

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DOWNSTREAM-RAL793-STALL.command` / `HERMES-DOWNSTREAM-ONLY.command` / `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent rebound to **hermes-mac-land** (not Ooterverse) with env LEGACY Hermes .11

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
