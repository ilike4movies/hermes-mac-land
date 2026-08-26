# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T04:55Z

## Live now (00:52 EDT containment)

RAL-820 successor canary **execution proved** on live `.11` (run `397968`), but a **new control-plane defect** was proven after recovery:

> Administrative RAL-820 state/label changes invalidated the recovery marker material signature and reopened the exact same contract without new Ralph direction.

### Duplicate worker runs (failed closed)

| Run | Outcome |
|-----|---------|
| `681664` (04:40Z) | Selected RAL-820, invoked local Qwen worker, failed closed |
| `693193` (04:45Z) | Same; 45,368 local tokens; no paid spend or false success |
| `705747` (04:50Z) | Zero-selection no-op |

### Containment (active)

- `cos-hermes-orchestrator.timer` **stopped** (read back inactive); service inactive
- RAL-820 restored to **In Review**; execution labels removed
- **Resume prohibited** until source correction installed + timer quiet no-op proves zero model/worker/Linear/Slack calls

### Already proved (do not re-litigate)

| Item | Evidence |
|------|----------|
| Execution | Run `397968`, `req-5d76e1f5e5544e6b`, worktree `executed\n` |
| Terminal | `VERIFIED_COMPLETE` + recovery marker `recovery-req-5d76e1f5e5544e6b` |
| Replay (04:34–04:38Z) | Cycles `667830`/`670382` excluded; `model_calls=0` |

### Next source fix (worker `bc-16d2fc78`)

Recovery markers must **survive state/label-only transitions** while preserving one-time reopening for genuine new material direction or explicit dispatch tokens.

Run `4007763` is **superseded** — do not replay `req-1e9dba0acd1e4cce`.

## Source state (`cos-local@ea62ea78`)

| PR | Fix |
|----|-----|
| [#93](https://github.com/ilike4movies/hermes-agent-cos/pull/93)–[#108](https://github.com/ilike4movies/hermes-agent-cos/pull/108) | Interrupt stack + replay quarantine + terminal reconcile + ledger marker |
| **In flight** | Recovery marker survives state/label-only transitions (regression) |

Open secondary: [PR #105](https://github.com/ilike4movies/hermes-agent-cos/pull/105) movement-SLA wall-clock (not on critical path). PR #101 closed as duplicate.

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** (run 397968) |
| RAL-820 replay quarantine | **FAILED** — state-only reopen defect; timer paused |
| RAL-800 tip-main `moltbot` land | **OPEN** |
| RAL-793 CLAIMED | **NO** — gated behind RAL-820 close |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge while linked to canary issues |

## Blocker order (current)

1. **Recovery marker state-transition fix** — source review + install + quiet no-op cycle
2. **RAL-820 acceptance** — close canary after replay quarantine re-proved
3. **RAL-793 dispatch** — after RAL-820 close
4. **RAL-800 tip-main apply** — credentialed land or Mac Hermes
5. **RAL-634 / WIP truth** — not started

## Live timeline (Aug 25–26)

| Time | Event |
|------|-------|
| 02:38Z | Run `397968` success — `executed\n` |
| 04:30Z | PR #108 merged; ledger marker published |
| 04:38Z | Acceptance cycles `667830`/`670382`: zero calls |
| 04:40–04:45Z | Runs `681664`/`693193`: duplicate worker (state-reopen defect) |
| 04:50Z | Run `705747`: zero-selection no-op |
| 04:52Z | Timer stopped; RAL-820 → In Review; source fix dispatched |

## ⚠️ Do not link PRs to RAL-798/820/793/800

Linear auto-Dones on PR merge and falsely closes canaries before `.11` prove-out.

## ⚠️ Ooterverse/mobile cannot land

Use credentialed `hermes-mac-land` agent on **LEGACY Hermes .11**:

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

Secrets required at boot: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`.
