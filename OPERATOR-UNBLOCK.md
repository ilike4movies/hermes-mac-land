# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T04:50Z

## Live now (04:38Z acceptance gate)

RAL-820 successor canary **execution proved** on live `.11`:

| Item | Evidence |
|------|----------|
| Execution | Run `20260826T023838783748Z-397968`, request `req-5d76e1f5e5544e6b` |
| Worktree | Isolated `subject.txt` = `executed\n`, deterministic test exit 0 |
| Terminal | `VERIFIED_COMPLETE` after PR #103/#106/#108 live recovery |
| Replay (04:34–04:38Z) | Cycles excluded `execution-verified-awaiting-objective-state-change`; `model_calls=0`, no duplicate worker |

**RAL-820 is at acceptance review.** Verify post-acceptance dispatcher `CLAIMED` runs (`681664`, `693193`) did not invoke executor before closing.

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
| RAL-820 `executed\n` + replay | **PARTIAL** — execution + replay yes; Ralph acceptance pending |
| RAL-800 tip-main `moltbot` land | **OPEN** — interrupt stack live via `hermes-agent-cos` surgical packets; wholesale tip-main apply not evidenced |
| RAL-793 CLAIMED | **NO** — Todo; gated behind RAL-820 close |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge while linked to canary issues |

## Blocker order (current)

1. **RAL-820 acceptance** — Ralph verify post-acceptance CLAIMs had no executor; close canary
2. **RAL-793 dispatch** — fresh interrupt under its own execution contract after RAL-820 close
3. **RAL-800 tip-main apply** — GitHub→`/opt/moltbot` drift closure (credentialed land or Mac Hermes)
4. **RAL-634 / WIP truth** — claimable-queue starvation alarms (not started)

## Live timeline (Aug 25–26)

| Time | Event |
|------|-------|
| 23:07Z | Run `4007763` terminal WAL mismatch → rollback `pending\n` |
| 23:34Z | PR #93 merged |
| 23:59Z | Comment dedupe collision canary — rolled back |
| 00:19Z | PR #96 canary: executor reached, allowlist violation |
| 02:38Z | **Run `397968` success** — `executed\n`, proof gate passed |
| 02:42Z | Replay defect: ordinary queue re-selected RAL-820 |
| 03:00Z | PR #102 merged + live replay-quarantine |
| 03:05Z | Active-request block: request stuck `WORKING` |
| 04:00Z | PR #103 merged; live recovery → `VERIFIED_COMPLETE` |
| 04:30Z | PR #108 merged; ledger marker published |
| 04:38Z | Acceptance cycles: zero worker/model calls |

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
