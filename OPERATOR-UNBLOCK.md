# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T08:54Z

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
| [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) | **merged → cos-local** — recovery ledger direction binding |
| [#125](https://github.com/ilike4movies/hermes-agent-cos/pull/125) | **merged → cos-local** — RAL-793 inventory contract stager |
| moltbot [#77](https://github.com/ilike4movies/moltbot/pull/77) | **MERGED** — drift check fails on missing interrupt |
| moltbot signal | **bumped** `20260826T084500Z-post-moltbot-77-drift-gate` (`8c0e76e1…`) |

### Critical path

1. ~~#121/#122 live apply + natural cycle~~ **DONE**
2. ~~moltbot #77 + SURGICAL_APPLY signal~~ **DONE** (await Host surgical-apply OK if watch installed)
3. ~~#115 + #125 on cos-local~~ **DONE** (need live apply / Stage A for host)
4. Credentialed `.11`: run `#125` stager / `docs/RAL-793-CONTRACT-STAGING.md` → pin contract → `DISPATCH-NOW RAL-793`
5. Prove Hermes **CLAIMED** + inventory evidence on RAL-793
6. Confirm RAL-800 tip-main land (proves RAL-634 WIP truth + RAL-799 auto-apply canary)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **OPEN** — signal bumped; needs watch OR Mac land / SSH secrets |
| RAL-793 CLAIMED | **NO** — blocked on pinned execution contract on host |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge while linked to canaries |

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent rebound to **hermes-mac-land** or **moltbot** (not Ooterverse)
- If jump/.11 already has `install-hermes-moltbot-cloud-apply-signal-watch.sh`, the 08:45Z signal bump should land within ~2m

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
