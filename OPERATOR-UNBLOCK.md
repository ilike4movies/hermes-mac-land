# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` (`four-openclaw`) **with inventory progress**. GitHub `main` alone is not sufficient.

**Updated:** 2026-08-25T22:26Z

## ⚠️ HOLD live DISPATCH-NOW retries (22:24Z)

Cooled retry at 22:21Z (CPU 53°C) hit **`failed_stale_claim`** — thermal pre-execution failure at 22:19Z left unreconciled prepare state on `req-1e9dba0acd1e4cce`.

**Do not post more `DISPATCH-NOW RAL-820`** until [hermes-agent-cos PR #92](https://github.com/ilike4movies/hermes-agent-cos/pull/92) merges to `cos-local` and Stage A redeploys with `reconcile_host_prepare_failure()`.

## ⚠️ Ooterverse / mobile override agents cannot land

Agents on `Ooterverse-Saturns-Quest` (including mobile override) **do not receive** `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` at boot. Tailscale stays `NeedsLogin`; no surgical land or Stage A is possible from those pods. Use path A, B, or C below on `hermes-mac-land` with **LEGACY Hermes .11** secrets.

## ⚠️ Do not link deploy/operator PRs to open canary issues

Linear auto-Dones linked issues on PR merge **without** live `.11` proof.

| Issue | Risk |
|-------|------|
| **RAL-800** | PR #11 + #12 falsely closed surgical-land gate — reopened twice |
| **RAL-820 / RAL-793** | `moltbot` PR #76 linked — do not merge until detached |
| **RAL-798** | Root interrupt ticket — keep PRs unlinked during prove-out |

Link operator/doc PRs to **RAL-799** or leave unlinked.

## ⚠️ moltbot PR #76 — do not merge yet

[`moltbot` PR #76`](https://github.com/ilike4movies/moltbot/pull/76) is linked in Linear to RAL-820 and RAL-793.

## Two live steps (do not conflate)

| Step | Ticket | What it does | Repo |
|------|--------|--------------|------|
| **1 — Surgical land** | RAL-800 | Lands `moltbot` tip on `/opt/moltbot` | `moltbot` via this repo |
| **2 — Stage A canary** | RAL-798 / RAL-820 | Control-loop adapter + RAL-820 fixture | `hermes-agent-cos` `cos-local` |

Stage A currently needs **`5bcb257e` + PR #92** (thermal reconcile) before next live retry.

## Live proof timeline (Aug 25)

| Time (UTC) | Event | Result |
|------------|-------|--------|
| 20:47Z | Stage A @ pre-#86 | Interrupt/claim pass; finalizer fail; rollback |
| 22:15–22:19Z | `DISPATCH-NOW` + Stage A @ `5bcb257e` | CLAIMED; thermal gate **99°C**; rollback |
| 22:21–22:24Z | Cooled retry (53°C) + fresh `DISPATCH-NOW` | **`failed_stale_claim`** — unreconciled prepare state |

## Source fix in flight

| PR | Status | Fix |
|----|--------|-----|
| [#92](https://github.com/ilike4movies/hermes-agent-cos/pull/92) | **Open** | `reconcile_host_prepare_failure()` — finalize/reconcile thermal-class pre-execution blocks; allow different-dedupe retry |

Host must call `reconcile_host_prepare_failure(reason="thermal_gate")` when thermal blocks after prepare.

## Current live state (readback 22:26Z)

| Check | Status |
|-------|--------|
| RAL-820 `subject.txt` → `executed` | **Open** |
| RAL-798 interrupt → executor | **Partial** — CLAIMED proven; stale-claim blocks retry |
| RAL-800 Host surgical-apply OK | **No** |
| RAL-793 CLAIMED + inventory | **No** — Todo |
| This pod | **Cannot land** |

## Blocker order (current)

1. **Merge PR #92** to `cos-local` + redeploy Stage A bundle
2. **RAL-800** credentialed surgical land (tip `moltbot` on `.11`)
3. **Stage A retry** @ post-#92 `cos-local` + `APPROVE-RJS-LIVE-BUNDLE-1`
4. **RAL-820** `subject.txt` = `executed\n`
5. **RAL-793** CLAIMED + inventory

## Pick one path

### A — New cloud agent (preferred)

Web UI → `ilike4movies/hermes-mac-land` + **LEGACY Hermes .11** + secrets at boot.

### B — Credentialed one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

### C — Mac Hermes

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
```

## Do not use

- More `DISPATCH-NOW` until PR #92 lands (stale-claim loop)
- Slack rockets as primary wake
- Ooterverse override for Hermes deploy
- Merging `moltbot` PR #76 while linked to canary issues
- Linking operator PRs to RAL-800/820/793/798
