# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-25T23:30Z

## Live now (23:07Z rollback)

Run `4007763` worker **did execute** (`pending` → `executed` in worktree) but RAL-733 finalizer failed `ral733-worker-result-wal-mismatch:api_calls` (6 WAL calls + denied 7th at ceiling). Safe rollback restored `subject.txt` = `pending\n`.

**Hold DISPATCH-NOW** until source lands + Stage A redeploys.

## Source state (`cos-local@36260a9f` + draft)

| PR | Status | Fix |
|----|--------|-----|
| [#86](https://github.com/ilike4movies/hermes-agent-cos/pull/86) | merged `5bcb257e` | WAL finalizer |
| [#90](https://github.com/ilike4movies/hermes-agent-cos/pull/90) | merged | Thermal/pre-execution reconcile |
| [#91](https://github.com/ilike4movies/hermes-agent-cos/pull/91) | merged `36260a9f` | Historical recovery-marker migration |
| [#93](https://github.com/ilike4movies/hermes-agent-cos/pull/93) | **draft** | `budget_exhausted` terminal + worker-failure reconcile |
| [#94](https://github.com/ilike4movies/hermes-agent-cos/pull/94) | **draft** | Wall-clock movement SLA on stalled CLAIMED |

**Merge order:** #93 → #94 → Stage A → fresh RAL-820 canary.

## Blocker order

1. **Merge #93+#94** + Stage A on `.11` (needs RAL-800 credentialed land)
2. **RAL-820** — prove `subject.txt` = `executed\n` + replay no-op
3. **RAL-793** CLAIMED + inventory

## ⚠️ Do not link PRs to RAL-798/820/793/800

## ⚠️ Ooterverse/mobile cannot land

Use credentialed `hermes-mac-land` agent on **LEGACY Hermes .11**:

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```
