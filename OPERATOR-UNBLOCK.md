# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-28T00:30Z

## ⚠️ Linear auto-Done hygiene

**Do NOT attach GitHub PRs to RAL-793, RAL-798, RAL-799, or RAL-634** while canaries are open — Linear auto-Dones on PR merge and falsely closes tickets before `.11` prove-out.

**Also:** do **not** put `RAL-793` (or other open canary IDs) in **PR titles** — GitHub auto-links on merge even when you do not attach manually.

| Incident | Cause | Fix |
|----------|-------|-----|
| 20:48Z | #18 merged + attached | Reverted; attachment detached @ 21:02Z |
| 21:29Z | #20 title contained `RAL-793` → auto-attach | Reverted @ 21:30Z; attachment detached |
| 21:38Z | MCP comment used wrong issue UUID → posted on RAL-800 | Corrected @ 21:40Z; see UUID table below |
| 01:04Z | Cloud subagent `bc-3914e61d` booted on **Ooterverse** (not hermes-mac-land) | Downstream FAILED pre-SSH; use Mac or web-UI LEGACY `.11` agent |
| 03:49Z | #40 auto-attached to RAL-634 (Done) | Detach if needed; do not re-open RAL-634 for doc-only merges |
| 04:22Z | Cloud subagent `bc-cf21d38f` spawned from Ooterverse | Skipped downstream to avoid FAILED spam; use Mac or web-UI `hermes-mac-land` + LEGACY `.11` |
| 23:45Z | OPERATOR UUID table had RAL-799/RAL-820 swapped; RAL-798 missing | Corrected: RAL-798=`52e94e17…`, RAL-799=`0d76e06f…`, RAL-820=`144b087c…` |

## ⚠️ Ooterverse cloud agents cannot run downstream

**Do not spawn Hermes subagents from Ooterverse-Saturns-Quest** — they inherit the wrong repo/env and cannot receive `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` at boot.

`hermes-dispatcher-downstream.sh` **fail-fast preflights** (since `60cf813` @ 04:12Z): missing `TS_AUTHKEY`/`HERMES_HOST_SSH_PRIVATE_KEY` fails in <1s even when `COMPOSER_REPO_URL` unset; Ooterverse repo also → `FAIL preflight: wrong_repo`.

**Only these paths work for live gates:**
1. **Mac Hermes** — double-click `HERMES-DOWNSTREAM-RAL793-STALL.command`
2. **Web UI cloud agent** — repo `ilike4movies/hermes-mac-land`, env **LEGACY Hermes .11**, secrets at boot

## Linear issue UUIDs (MCP / API comment posting)

When posting via Linear MCP `save_comment`, **verify `issueId` UUID** — do not guess from subscriptions.

| Ticket | UUID | Status |
|--------|------|--------|
| **RAL-793** | `963472c8-cc84-426a-9ed6-79e08566353a` | In Progress — **sole remaining program blocker** (stall `2954673`) |
| **RAL-634** | `1b5a7e86-1d14-456f-b0d1-39a02df243c2` | **Done** — live #103 transition dedupe proof @ 03:35–03:45Z |
| **RAL-798** | `52e94e17-69e6-4688-a60e-aea25b090ebf` | In Progress — WIP-park **#110 LIVE** on `.11` (canary PASS @ 00:05Z, SHA `b3b82bf2…`); stays open for broader interrupt/acceptance |
| **RAL-799** | `0d76e06f-bf49-4587-a733-1b6f397f1392` | **Done** — GitHub→host apply + drift |
| **RAL-800** | `dae80aa2-e6d0-4225-9ae8-cdb72ccd8ec0` | **Done** — host-land only |
| **RAL-820** | `144b087c-79f2-4a31-aa21-a98357547843` | **Done** — interrupt→executor canary |

**Prefer ticket identifiers in scripts** (`HERMES_RAL793_LINEAR_TICKET=RAL-793`) — scripts resolve via `issueSearch`. MCP agents must use UUIDs explicitly.

## Machine status inbox (GitHub)

[hermes-mac-land issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) receives machine posts when Mac/credentialed runs execute.

## Live stall — RAL-793 run `2954673` (CLAIMED @ 23:25Z 2026-08-26, silent ~24.8h+)

| Item | Status |
|------|--------|
| Run ID | `20260826T232521106484Z-2954673` |
| CLAIMED | **YES** @ 23:25:30Z via `hermes-now` / DISPATCH-NOW |
| Contract readback | **MISSING** |
| Inventory `evidence/RAL-793-inventory.md` | **MISSING** |
| `## Downstream STARTED` / `DONE` | **NO** credentialed success yet |
| Operator wake | Gmail ACTION + URGENT (bumped `1a045b8de4d4daae` @ 00:25Z) — open STALL.command |

### Fastest unblock (Mac Hermes, Tailscale up)

**Double-click:** [`HERMES-DOWNSTREAM-RAL793-STALL.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command)

```bash
HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
```

**Stall defaults (#56 @ `3ed31e5`):** `HERMES_AUTO_STACK_APPLY=0` (`.11` already at #110 tip) + `HERMES_STALL_RECOVERY=1` + dual DISPATCH-NOW (#52). Set stack-apply=1 only if host drifts.

**Downstream chain:** inspect → contract install → skip stack-apply → dual DISPATCH-NOW → RAL-634 verify.

## Program gates (2026-08-28)

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Linear interrupt | **DONE** — RAL-793 CLAIMED @ 23:25Z |
| 2 | GitHub→`.11` auto-apply + drift | **DONE** (RAL-799) |
| 3 | WIP truth / RAL-634 class | **DONE** — #103 live + #110 WIP-park canary PASS @ 00:05Z |
| 4 | Miss/idle alarms | **DONE** |
| 5 | RAL-793 canary + inventory | **OPEN** — sole blocker |
| 6 | Operator docs | **Sync** — this tip (#110 live + #56 skip stack-apply) |

### Source follow-ups (recent)

| PR | Status |
|----|--------|
| moltbot [#110](https://github.com/ilike4movies/moltbot/pull/110) | **MERGED + LIVE on `.11`** — canary PASS @ 00:05Z (`b3b82bf2…` / `a535cb7`) |
| hermes-mac-land [#56](https://github.com/ilike4movies/hermes-mac-land/pull/56) | **merged** @ `3ed31e5` — stall defaults skip stack-apply after tip verified |
| hermes-mac-land [#55](https://github.com/ilike4movies/hermes-mac-land/pull/55) / [#54](https://github.com/ilike4movies/hermes-mac-land/pull/54) / [#53](https://github.com/ilike4movies/hermes-mac-land/pull/53) | **merged** — docs + temporary stack-apply=1 window |
| hermes-mac-land [#52](https://github.com/ilike4movies/hermes-mac-land/pull/52) | **merged** — dual DISPATCH-NOW stall recovery |

### Critical path (remaining)

1. ~~Interrupt + apply + WIP-park~~ **DONE**
2. **Credentialed downstream** → contract readback on RAL-793 → inventory evidence
3. RAL-794 handoff comment (blocked on #2)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** |
| moltbot #110 on `/opt/moltbot` | **VERIFIED PASS** @ 00:05Z |
| RAL-634 starvation alarm | **Done** |
| RAL-793 contract + inventory | **OPEN** — run `2954673` stalled |
| Operator scripts on main | **Done** (#52 dual-dispatch; #56 skip stack-apply) |

## Credentialed run (Mac)

- **`HERMES-DOWNSTREAM-RAL793-STALL.command`** — pins `2954673`; stack-apply=0; stall recovery + dual DISPATCH-NOW

Success receipts: GitHub #1 Downstream STARTED→DONE; RAL-793 contract readback; `evidence/RAL-793-inventory.md`.

## ⚠️ Hermes work: hermes-mac-land / hermes-agent-cos / moltbot only — not Ooterverse
