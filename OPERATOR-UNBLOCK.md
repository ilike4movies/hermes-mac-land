# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T21:31Z

## ⚠️ Linear auto-Done hygiene

**Do NOT attach GitHub PRs to RAL-793, RAL-798, RAL-799, or RAL-634** while canaries are open — Linear auto-Dones on PR merge and falsely closes tickets before `.11` prove-out.

**Also:** do **not** put `RAL-793` (or other open canary IDs) in **PR titles** — GitHub auto-links on merge even when you do not attach manually.

| Incident | Cause | Fix |
|----------|-------|-----|
| 20:48Z | #18 merged + attached | Reverted; attachment detached @ 21:02Z |
| 21:29Z | #20 title contained `RAL-793` → auto-attach | Reverted @ 21:30Z; attachment detached |

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
| RAL-793 inventory evidence | **OPEN** |
| RAL-634 starvation alarm | **OPEN** — live prove-out pending |

## Credentialed run commands (Mac / cloud agent with SSH secrets)

### Mac double-click (recommended when RAL-800/799 already Done)

- **`HERMES-DOWNSTREAM-ONLY.command`** — contract install + auto DISPATCH-NOW + RAL-634 verify (no land)
- **`HERMES-DIAGNOSE-THEN-LAND.command`** — full diagnose + land (when tip refresh needed)

### Shell one-liners

```bash
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

On boot with secrets, `hermes-cloud-agent-start.sh` now chains downstream gates by default (`HERMES_AUTO_DOWNSTREAM=1`). Set `HERMES_AUTO_SURGICAL_LAND=0` for downstream-only boot.

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DOWNSTREAM-ONLY.command` / `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent rebound to **hermes-mac-land** (not Ooterverse) with env LEGACY Hermes .11

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
