# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T08:30Z

## Live now — RAL-820 Done; zero-model canary proved

| Item | Evidence |
|------|----------|
| Canary | Run `1097131`, `req-c8a22ccbc2504e6b`, `VERIFIED_COMPLETE`, **0** model/API/tool calls |
| Replay | `1099734` = `healthy_noop` |
| Timer | Active (5m) |
| RAL-820 | **Done** |

### Source follow-ups

| PR | Status |
|----|--------|
| [#121](https://github.com/ilike4movies/hermes-agent-cos/pull/121) | **merged** — preserve 0755 modes on apply |
| [#123](https://github.com/ilike4movies/hermes-agent-cos/pull/123) | **draft** — DISPATCH-NOW comment pagination |
| [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) | **draft** — direction binding |

### Critical path

1. #121 live apply + natural scheduled cycle readback
2. #123 review/merge/install
3. Dispatch **RAL-793** under its own contract (inventory first)
4. RAL-800 tip-main land (proves RAL-634)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| RAL-820 canary + quiet replay | **PROVED / Done** |
| RAL-800 tip-main land | **OPEN** |
| RAL-793 CLAIMED | **NO** — next product canary |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge |

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
