# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T06:50Z

## Live now

RAL-820 execution **proved** once (run `397968`), then a **state-only reopen defect** caused duplicate workers (`681664`/`693193`). Timer stopped. Interrupt-dismissal stack (#109/#110) applied live; fresh canary `861845` force-selected correctly but hit `budget-ceiling-breached:api_calls` (6 local calls, ~45k tokens, zero paid).

### Containment

- `cos-hermes-orchestrator.timer` **stopped**; service inactive
- Resume prohibited until: verified terminal canary success + quiet no-op replay

### Source stack

| PR | Status | Role |
|----|--------|------|
| [#109](https://github.com/ilike4movies/hermes-agent-cos/pull/109) | **merged** `411f3e08` | Interrupt dismissal memory |
| [#110](https://github.com/ilike4movies/hermes-agent-cos/pull/110) | **merged** `40e20458` + live apply | Incremental stager; live dispatcher `ff74e375…` |
| [#112](https://github.com/ilike4movies/hermes-agent-cos/pull/112) | **draft / rework** | Tiny deterministic route — avoids 6-call budget burn on RAL-820 |
| [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) | **draft** | Recovery ledger direction binding (state/label admin reopen) |

### Critical path

1. **PR #112** review pass → merge → live apply (deterministic/tiny route)
2. Fresh RAL-820 canary → verified terminal (no budget breach)
3. **PR #115** merge/install (state-only reopen quarantine)
4. Quiet no-op replay (zero model/worker/Linear/Slack)
5. Close RAL-820 → dispatch RAL-793
6. RAL-800 tip-main land + RAL-634 WIP truth

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** (397968); reopen/budget defects remain |
| RAL-820 replay quarantine | **OPEN** — #115 drafted; #112 needed for efficient canary |
| RAL-800 tip-main land | **OPEN** |
| RAL-793 CLAIMED | **NO** |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge while linked to canaries |

## ⚠️ Do not link PRs to RAL-798/820/793/800

## ⚠️ Ooterverse/mobile cannot land

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

Secrets: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY` on **LEGACY Hermes .11**.
