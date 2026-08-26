# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T07:05Z

## Live now

RAL-820 execution **proved** once (run `397968`), then state-only reopen + budget-ceiling failures. Timer stopped. #109/#110 live. Canary `861845` budget-failed.

### Source stack

| PR | Status | Role |
|----|--------|------|
| [#109](https://github.com/ilike4movies/hermes-agent-cos/pull/109)/[#110](https://github.com/ilike4movies/hermes-agent-cos/pull/110) | **merged + live** | Interrupt dismissal + incremental stager |
| [#112](https://github.com/ilike4movies/hermes-agent-cos/pull/112) | **draft — source review PASS** (07:04Z) | Tiny/deterministic route; awaiting `.11` clean-checkout then merge/live |
| [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) | **draft** | Recovery ledger direction binding |

### Critical path

1. `.11` clean-checkout confirm **#112** → merge → live apply
2. Fresh RAL-820 canary → verified terminal (zero budget burn)
3. **#115** merge/install → quiet no-op replay
4. Close RAL-820 → dispatch RAL-793
5. **RAL-800** tip-main land (also lands RAL-634 verifier — `detect_queue_starvation` already on `moltbot` main)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** (397968); reopen/budget remain |
| RAL-820 canary + quiet replay | **OPEN** — #112 source PASS; live pending |
| RAL-800 tip-main land | **OPEN** — secrets missing on Ooterverse pod |
| RAL-634 starvation verifier | **SOURCE ON tip-main** — prove-out blocked on RAL-800 land |
| RAL-793 CLAIMED | **NO** |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge |

## ⚠️ Do not link PRs to RAL-798/820/793/800

## ⚠️ Ooterverse/mobile cannot land

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

Secrets: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY` on **LEGACY Hermes .11**.
