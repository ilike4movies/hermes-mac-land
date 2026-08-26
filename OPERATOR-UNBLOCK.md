# Hermes dispatcher — operator unblock (tip-main land)

**Hard gate:** media-studio inventory ticket must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T09:04Z

## Live now — interrupt canary Done; #121/#122 installed

| Item | Evidence |
|------|----------|
| Canary | Run `1097131`, `req-c8a22ccbc2504e6b`, `VERIFIED_COMPLETE`, **0** model/API/tool calls |
| Replay | `1099734` = `healthy_noop` |
| Comment discovery | hermes-agent-cos [#122](https://github.com/ilike4movies/hermes-agent-cos/pull/122) **merged + live** |
| Natural cycle | `1131057` / dispatcher `1131978` = `healthy_noop` |
| Timer | Active (5m) |

### Source follow-ups

| PR | Status |
|----|--------|
| hermes-agent-cos #115 / #125 | **merged → cos-local** |
| moltbot [#76](https://github.com/ilike4movies/moltbot/pull/76) | **MERGED** — safer post-apply canary default |
| moltbot [#77](https://github.com/ilike4movies/moltbot/pull/77) | **MERGED** — drift fails on missing interrupt |
| moltbot [#78](https://github.com/ilike4movies/moltbot/pull/78) | **MERGED** — miss/idle watchdog on timers |
| moltbot signal | **bumped** `20260826T090400Z-post-moltbot-76-78-miss-idle` |

### Critical path

1. ~~Source stack (#76/#77/#78 + #115/#125)~~ **DONE**
2. Host surgical-apply OK (watch / Mac / credentialed) — **OPEN**
3. Stage inventory contract (`docs/RAL-793-CONTRACT-STAGING.md`) → DISPATCH-NOW
4. CLAIMED + inventory evidence; RAL-634 prove-out

## This pod cannot land tip-main

Needs `TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` on hermes-mac-land, or Mac Hermes double-click.

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
