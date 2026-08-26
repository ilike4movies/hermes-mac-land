# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T06:45Z

## Live now (00:52 EDT containment)

RAL-820 execution **proved** (run `397968`), but a **state-only reopen defect** caused duplicate worker runs `681664`/`693193` after admin state/label changes invalidated recovery marker binding.

### Containment (active)

- `cos-hermes-orchestrator.timer` **stopped**; service inactive
- RAL-820 **In Review**; execution labels removed
- **Resume prohibited** until fix installed + quiet no-op cycle

### Source fix in flight

| PR | Fix |
|----|-----|
| [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) | Recovery ledger binds on direction material (title+description) only — survives state/label admin changes |
| [#109](https://github.com/ilike4movies/hermes-agent-cos/pull/109) | Interrupt dismissal memory for quiet no-op cycles (orthogonal) |

Merge order: **#115** → install → quiet no-op prove → resume timer → RAL-820 acceptance close.

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** (run 397968) |
| RAL-820 replay quarantine | **FAILED** — state-only reopen; fix in PR #115 |
| RAL-800 tip-main `moltbot` land | **OPEN** |
| RAL-793 CLAIMED | **NO** — gated behind RAL-820 close |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge while linked to canary issues |

## Blocker order

1. **PR #115** review + live install + quiet no-op cycle
2. **RAL-820 acceptance** close after replay re-proved
3. **RAL-793 dispatch** under its own contract
4. **RAL-800** credentialed tip-main land
5. **RAL-634 / WIP truth** — not started

## ⚠️ Do not link PRs to RAL-798/820/793/800

Linear auto-Dones on PR merge and falsely closes canaries before `.11` prove-out.

## ⚠️ Ooterverse/mobile cannot land

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

Secrets: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY` on **LEGACY Hermes .11** environment.
