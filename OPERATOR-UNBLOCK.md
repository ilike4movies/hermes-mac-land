# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T07:50Z

## Live now

| Event | Status |
|-------|--------|
| Run `397968` | Execution proved once |
| State-only reopen | Duplicate workers `681664`/`693193`; timer stopped |
| PR #112 | **merged** — tiny/deterministic route |
| PR #118 | **merged** — incremental deploy closure |
| Live preflight | **FAILED CLOSED** — `consumer-contract-objective-mismatch:RAL-820` (stager expected long objective; live preimage has short objective) |
| PR #115 | Draft — direction binding (after canary) |

**No live mutation** from #118 preflight. Timer inactive.

### Critical path

1. Narrow follow-up: byte-preserve live RAL-820 objective; sole delta = `implementation_action`
2. Live apply + zero-model RAL-820 canary → verified terminal
3. PR #115 install → quiet no-op replay
4. Close RAL-820 → RAL-793
5. RAL-800 tip-main land (proves RAL-634 starvation verifier already on tip-main)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED**; reopen/budget/deploy remain |
| RAL-820 canary + quiet replay | **OPEN** — deploy follow-up after #118 objective mismatch |
| RAL-800 tip-main land | **OPEN** |
| RAL-634 | Source on tip-main; prove via RAL-800 |
| RAL-793 CLAIMED | **NO** |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge |

## ⚠️ Do not link PRs to RAL-798/820/793/800

## ⚠️ Ooterverse/mobile cannot land Hermes deploy

Credentialed agent with Tailscale/SSH exists but must bind to `hermes-mac-land`/`moltbot`, not Ooterverse.
