# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T21:10Z

## ⚠️ Linear auto-Done hygiene

**Do NOT attach GitHub PRs to RAL-793, RAL-798, RAL-799, or RAL-634** while canaries are open — Linear auto-Dones on PR merge and falsely closes tickets before `.11` prove-out.

RAL-793 was falsely auto-Done @ 20:48Z when hermes-mac-land #18 merged (operator scripts only, no inventory). Reverted to In Progress.

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

### Critical path (remaining)

1. ~~Interrupt + apply gates~~ **DONE** (RAL-820, RAL-800, RAL-799)
2. **`hermes-dispatcher-downstream.sh`** or contract install → readback → `DISPATCH-NOW RAL-793`
3. Prove inventory evidence on RAL-793 (not WORK-PACKET-DONE alone)
4. **`hermes-ral634-starvation-verify.sh --post-linear`** prove-out on live verifier

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **Done** @ 20:21Z |
| RAL-799 live prove-out | **Done** @ 20:22Z — canary+drift verified |
| Local cloud-apply watch (#79) | **installed** @ 19:14Z surgical-apply |
| Operator scripts on main (#18) | **Done** @ 21:00Z |
| RAL-793 contract pinned | **OPEN** — run contract install script |
| RAL-793 inventory evidence | **OPEN** — falsely auto-Done @ 20:48Z, reverted |
| RAL-634 starvation alarm | **OPEN** — source on main; live prove-out pending |

## Credentialed run commands (Mac / cloud agent with SSH secrets)

```bash
# Downstream gates: contract install + RAL-634 verify
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Or individually:
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh | bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh | bash -s -- --post-linear
```

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent rebound to **hermes-mac-land** or **moltbot** (not Ooterverse)

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
