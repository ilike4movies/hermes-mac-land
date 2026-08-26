# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T08:05Z

## Live now

| PR | Status |
|----|--------|
| #112 | **merged** — tiny/deterministic route |
| #118 | **merged** — incremental deploy closure |
| #120 | **merged** — live short RAL-820 objective preserve |
| #115 | **draft** — direction binding (post-canary) |

#118 live preflight failed on objective mismatch; **#120** repairs that. Next gated step: live apply of #120 packet + zero-model RAL-820 canary. Timer inactive. No false Done from stale receipts.

### Critical path

1. Live apply #120 incremental packet (backup/readback/rollback)
2. Zero-model RAL-820 canary → verified terminal
3. #115 install → quiet no-op replay
4. Close RAL-820 → RAL-793
5. RAL-800 tip-main land (also proves RAL-634)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED**; deploy/canary remain |
| RAL-820 canary + quiet replay | **OPEN** — source ready (#112/#118/#120); live apply pending |
| RAL-800 tip-main land | **OPEN** |
| RAL-634 | Source on tip-main; prove via RAL-800 |
| RAL-793 CLAIMED | **NO** |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge |

## ⚠️ Do not link PRs to RAL-798/820/793/800

## ⚠️ Deploy env must be hermes-mac-land/moltbot — not Ooterverse
