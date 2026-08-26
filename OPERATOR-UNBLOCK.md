# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T09:20Z

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
| moltbot [#76](https://github.com/ilike4movies/moltbot/pull/76) | **merged** — post-apply canary default away from media-studio |
| moltbot [#77](https://github.com/ilike4movies/moltbot/pull/77) | **merged** — drift check fails on missing interrupt |
| moltbot [#78](https://github.com/ilike4movies/moltbot/pull/78) | **merged** — miss/idle watchdog + timers |
| moltbot [#79](https://github.com/ilike4movies/moltbot/pull/79) | **merged** — surgical-apply installs **local** cloud-apply watch |

### Critical path

1. ~~#121/#122 live apply + natural cycle~~ **DONE**
2. **Mac / credentialed land tip** (lands #79 → installs local cloud-apply watch on `.11`)
3. Stage **RAL-793 execution contract** on `.11` (see `docs/RAL-793-CONTRACT-STAGING.md`), then `hermes-now` / `DISPATCH-NOW RAL-793`
4. Prove Hermes **CLAIMED** + inventory evidence on RAL-793
5. RAL-800 tip-main land complete (proves RAL-634 starvation alarm on live verifier)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **OPEN** — needs credentialed SSH / Mac land (watch absent until first land) |
| Local cloud-apply watch (#79) | **source ready** — activates on next surgical-apply |
| RAL-793 CLAIMED | **NO** — blocked on pinned execution contract |

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent rebound to **hermes-mac-land** or **moltbot** (not Ooterverse)

Signal bumps alone do **not** land until a watch exists (jump or local). #79 makes the next direct-`.11` surgical-apply install the local watch so later bumps work without rockets.

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
