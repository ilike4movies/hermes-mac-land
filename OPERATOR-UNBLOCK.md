# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T04:52Z

## Live now (RAL-820 acceptance gate)

RAL-820 successor canary **execution proved** on live `.11`:

| Item | Evidence |
|------|----------|
| Execution | Run `20260826T023838783748Z-397968`, request `req-5d76e1f5e5544e6b` |
| Worktree | Isolated `subject.txt` = `executed\n`, deterministic test exit 0 |
| Terminal | `VERIFIED_COMPLETE` after PR #103/#106/#108 live recovery |
| Replay (04:34–04:38Z) | Cycles `667830`/`670382` excluded; `model_calls=0`, no duplicate worker |

**RAL-820 returned to In Progress** after timer-restored wakes posted post-acceptance `CLAIMED` comments (runs `681664` @ 04:40Z, `693193` @ 04:45Z). Ralph must read back both runs before close.

### ⚠️ CLAIM comment text is NOT acceptance evidence

Every `CLAIMED` comment includes `Candidate model route: … (not invoked by dispatcher)` — including run `397968` where the worker **did** execute. That phrase only means the dispatcher does not call the model directly.

### Required readback (runs `681664`, `693193`)

On `.11`, confirm for each post-acceptance run:

1. `execution_evidence.json` shows `executor_started=false`, `model_calls=0`, tokens=0
2. No new worker run dir under `…/home/runtime/ral798/runs/` after `397968`
3. Canary worktree `subject.txt` still `executed\n`; canonical fixture unchanged
4. Outcome = `execution-verified-awaiting-objective-state-change` (exclusion), not fresh mission

Run `4007763` is **superseded** (terminal WAL mismatch 23:07Z) — do not replay `req-1e9dba0acd1e4cce`.

## Source state (`cos-local@ea62ea78`)

| PR | Fix |
|----|-----|
| [#93](https://github.com/ilike4movies/hermes-agent-cos/pull/93) | WAL `budget_exhausted` + worker failure reconcile |
| [#95](https://github.com/ilike4movies/hermes-agent-cos/pull/95) | Surgical RAL-733 live packet |
| [#96](https://github.com/ilike4movies/hermes-agent-cos/pull/96) | Stable Linear comment interrupt identity |
| [#97](https://github.com/ilike4movies/hermes-agent-cos/pull/97)–[#98](https://github.com/ilike4movies/hermes-agent-cos/pull/98) | Consumer allowlist + live preimage delta |
| [#102](https://github.com/ilike4movies/hermes-agent-cos/pull/102) | Verified-execution replay quarantine |
| [#103](https://github.com/ilike4movies/hermes-agent-cos/pull/103) | Terminal `VERIFIED_COMPLETE` reconciler |
| [#106](https://github.com/ilike4movies/hermes-agent-cos/pull/106) | Movement path via orchestrator run id |
| [#108](https://github.com/ilike4movies/hermes-agent-cos/pull/108) | Recovery `execution_verified` ledger marker |

Open secondary: [PR #105](https://github.com/ilike4movies/hermes-agent-cos/pull/105) movement-SLA wall-clock (not on critical path).

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** (RAL-820 run 397968) |
| RAL-820 `executed\n` + replay | **PARTIAL** — execution + replay yes; post-acceptance CLAIM readback pending |
| RAL-800 tip-main `moltbot` land | **OPEN** — interrupt stack live via `hermes-agent-cos` surgical packets; wholesale tip-main apply not evidenced |
| RAL-793 CLAIMED | **NO** — Todo; gated behind RAL-820 close |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge while linked to canary issues |

## Blocker order (current)

1. **RAL-820 acceptance** — readback runs `681664`/`693193` for zero executor; close canary
2. **RAL-793 dispatch** — fresh interrupt under its own execution contract after RAL-820 close
3. **RAL-800 tip-main apply** — GitHub→`/opt/moltbot` drift closure (credentialed land or Mac Hermes)
4. **RAL-634 / WIP truth** — claimable-queue starvation alarms (not started)

## Live timeline (Aug 25–26)

| Time | Event |
|------|-------|
| 23:07Z | Run `4007763` terminal WAL mismatch → rollback `pending\n` |
| 23:34Z | PR #93 merged |
| 02:38Z | **Run `397968` success** — `executed\n`, proof gate passed |
| 03:00Z | PR #102 merged + live replay-quarantine |
| 04:00Z | PR #103 merged; live recovery → `VERIFIED_COMPLETE` |
| 04:30Z | PR #108 merged; ledger marker published |
| 04:38Z | Acceptance cycles `667830`/`670382`: zero worker/model calls |
| 04:40Z | Post-acceptance CLAIM run `681664` — readback pending |
| 04:45Z | Post-acceptance CLAIM run `693193` — readback pending |

## ⚠️ Do not link PRs to RAL-798/820/793/800

Linear auto-Dones on PR merge and falsely closes canaries before `.11` prove-out.

## ⚠️ Ooterverse/mobile cannot land

Use credentialed `hermes-mac-land` agent on **LEGACY Hermes .11**:

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

Secrets required at boot: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`.

## One-liner chain (after credentialed land)

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
# then Stage A preflight + deploy per hermes-agent-cos deployment-packet.md
```
