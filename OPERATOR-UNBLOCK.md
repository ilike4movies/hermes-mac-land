# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-25T23:00Z

## Live now (22:58Z)

Post-PR #91 Stage A retry: **CLAIMED** at 22:58:56Z (`run 4007763`). Awaiting executor + `subject.txt` = `executed\n`.

## Source state (`cos-local@36260a9f`)

| PR | Merge | Fix |
|----|-------|-----|
| [#86](https://github.com/ilike4movies/hermes-agent-cos/pull/86) | `5bcb257e` | WAL finalizer |
| [#90](https://github.com/ilike4movies/hermes-agent-cos/pull/90) | `e156bf9b` | Thermal/pre-execution reconcile |
| [#91](https://github.com/ilike4movies/hermes-agent-cos/pull/91) | `36260a9f` | Historical recovery-marker migration |

PR #92 closed as duplicate of #90+#91.

## Tonight's live timeline

| Time | Event |
|------|-------|
| 22:15–22:19Z | Thermal gate 99°C — fail-closed |
| 22:21Z | Cooled retry → `failed_stale_claim` |
| 22:36Z | PR #90 live retry → historical marker block |
| 22:54Z | PR #91 merged |
| 22:58Z | **CLAIMED** run `4007763` |

## Blocker order

1. **RAL-820 executor** — prove `subject.txt` = `executed\n` (run 4007763 in flight)
2. **RAL-800** credentialed surgical land (no Host OK since Aug 22)
3. **RAL-793** CLAIMED + inventory

## ⚠️ Do not link PRs to RAL-798/820/793/800

PR #90 falsely auto-Doned RAL-798 at 22:34Z — reopened at 22:46Z.

## ⚠️ Ooterverse/mobile cannot land

Use credentialed `hermes-mac-land` agent on **LEGACY Hermes .11**:

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```
