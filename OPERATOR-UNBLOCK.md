# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T21:00Z

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
| moltbot [#76](https://github.com/ilike4movies/moltbot/pull/76) | **merged** — post-apply canary default away from media-studio |
| moltbot [#77](https://github.com/ilike4movies/moltbot/pull/77) | **merged** — drift check fails on missing interrupt |
| moltbot [#78](https://github.com/ilike4movies/moltbot/pull/78) | **merged** — miss/idle watchdog + timers |
| moltbot [#79](https://github.com/ilike4movies/moltbot/pull/79) | **merged** — surgical-apply installs **local** cloud-apply watch |
| hermes-mac-land [#18](https://github.com/ilike4movies/hermes-mac-land/pull/18) | **merging** — live verify + RAL-793 contract install + RAL-634 starvation verify |

### Critical path (remaining)

1. ~~#121/#122 live apply + natural cycle~~ **DONE**
2. ~~Mac / credentialed land tip~~ **DONE** @ 20:21Z (RAL-800)
3. ~~RAL-799 live verify~~ **Done** @ 20:22Z
4. **`hermes-ral793-contract-install.sh`** → readback → `DISPATCH-NOW RAL-793`
5. Prove Hermes **CLAIMED** + inventory evidence on RAL-793 (not WORK-PACKET-DONE alone)
6. **`hermes-ral634-starvation-verify.sh --post-linear`** prove-out on live verifier

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| Comment poll freshness (#122) | **PROVED / live** |
| RAL-800 tip-main land | **Done** @ 20:21Z |
| RAL-799 live prove-out | **Done** @ 20:22Z — canary+drift verified |
| Local cloud-apply watch (#79) | **installed** @ 19:14Z surgical-apply |
| RAL-793 contract pinned | **OPEN** — run contract install script |
| RAL-793 CLAIMED + inventory | **PARTIAL** — CLAIMED @ 12:55Z; inventory evidence missing |
| RAL-634 starvation alarm | **OPEN** — source on main; live prove-out pending |

## Credentialed run commands (Mac / cloud agent with SSH secrets)

After hermes-mac-land #18 merges to `main`:

```bash
# Full chain: land → preflight → RAL-799 verify → RAL-634 verify
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash

# RAL-793 contract staging (does NOT dispatch)
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh | bash

# RAL-634 starvation prove-out
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral634-starvation-verify.sh | bash -s -- --post-linear
```

Until #18 merges, substitute branch `cursor/ral799-live-verify-3436` for `main` in URLs above.

## This pod cannot land tip-main

Cloud agents on Ooterverse lack `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY`. Land via:

- Mac Hermes: `HERMES-DIAGNOSE-THEN-LAND.command` / `hermes-credentialed-resume-land.sh`
- Credentialed agent rebound to **hermes-mac-land** or **moltbot** (not Ooterverse)

Signal bumps alone do **not** land until a watch exists (jump or local). #79 makes the next direct-`.11` surgical-apply install the local watch so later bumps work without rockets.

Credentialed resume-land / cloud-agent-start now **jump-first** by default (`HERMES_PREFER_DIRECT_HOST=0`) so grok-cos-1 gets the watch when reachable; set `=1` to force direct `.11` only (Mac LAN path still defaults to direct).

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
