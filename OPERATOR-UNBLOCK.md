# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` (`four-openclaw`) **with inventory progress**. GitHub `main` alone is not sufficient.

**Updated:** 2026-08-25T22:05Z

## ⚠️ Ooterverse / mobile override agents cannot land

Agents on `Ooterverse-Saturns-Quest` (including mobile override) **do not receive** `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` at boot. Tailscale stays `NeedsLogin`; no surgical land or Stage A is possible from those pods. Use path A, B, or C below on `hermes-mac-land` with **LEGACY Hermes .11** secrets.

## ⚠️ moltbot PR #76 — do not merge yet

[`moltbot` PR #76](https://github.com/ilike4movies/moltbot/pull/76) is **linked in Linear to RAL-820 and RAL-793**. Merging while attached may auto-Done those issues before live `.11` proof.

Land scripts on `hermes-mac-land` `main` already export `HERMES_POST_APPLY_CANARY=RAL-820` — merge PR #76 only after detaching from canary issues or after canary proof.

## Two live steps (do not conflate)

| Step | Ticket | What it does | Repo | Auto on cloud boot? |
|------|--------|--------------|------|-------------------|
| **1 — Surgical land** | RAL-800 | Lands `moltbot` tip on `/opt/moltbot` (interrupt label, WIP park, apply watch, drift) | `moltbot` via this repo | **Yes** — `hermes-cloud-agent-start.sh` |
| **2 — Stage A canary** | RAL-798 / RAL-820 | Installs `hermes-agent-cos` control-loop adapter + runs bounded RAL-820 canary (`subject.txt` → `executed`) | `hermes-agent-cos` `cos-local` @ **`5bcb257e`** (PR #86) | **No** — bounded activation manual; **read-only source + live preflight** auto after land |

**Preflight chain (read-only, auto after land):**
1. `hermes-stage-a-source-preflight.sh` — validates `cos-local@5bcb257e` source (no SSH; needs `gh`)
2. `hermes-stage-a-preflight.sh` — validates live `.11` preimage + canary fixture (needs SSH)

Surgical land alone does **not** deploy PR #82+#83 comment-first interrupt discovery. Stage A is required for `DISPATCH-NOW` without `hermes-now` and for the RAL-820 fixture proof.

After Step 1 succeeds, a credentialed agent on `.11` must run Stage A per `hermes-agent-cos` `ops/ral798-control-loop/deployment-packet.md` @ `5bcb257e`.

## RAL-798 source bundle — **complete at source** (21:38Z)

| PR | Merge | Fix |
|----|-------|-----|
| [#82](https://github.com/ilike4movies/hermes-agent-cos/pull/82) | `cef81c9` | `DISPATCH-NOW` discoverable without `hermes-now`; fresh comment interrupts rank before standing labels |
| [#83](https://github.com/ilike4movies/hermes-agent-cos/pull/83) | `5e77535` | Fresh interrupt with different dedupe may create new request after terminal FAILED |
| [#84](https://github.com/ilike4movies/hermes-agent-cos/pull/84) | `cbb31dba` | Minimal `finalize_worker_session_usage` (superseded by #86 WAL path) |
| [#85](https://github.com/ilike4movies/hermes-agent-cos/pull/85) | `054895ab` | Bundle manifest guard hash refresh |
| [#86](https://github.com/ilike4movies/hermes-agent-cos/pull/86) | **`5bcb257e`** | Identity-bound WAL finalizer + durable `reportback_verified=true` |

**21:38Z:** PR #86 merged to `cos-local`. **Stage A source gate cleared.** Next: credentialed bounded Stage A retry on `.11` with preserved `DISPATCH-NOW RAL-820` comment.

**21:54Z:** `hermes-mac-land` PR [#8](https://github.com/ilike4movies/hermes-mac-land/pull/8) merged — cloud land auto-chains read-only Stage A preflight after successful surgical apply.

**20:47Z live proof (PR #82+#83):** interrupt/discovery/claim **passed**; worker failed `ral733-core-worker-finalizer-missing`; rolled back 20:49Z. Host at healthy preimage `2cb904b8…`; timer active/enabled.

## Current live state (readback 21:57Z)

| Check | Status |
|-------|--------|
| RAL-820 successor canary (`subject.txt` → `executed`) | **Open** — source ready @ `5bcb257e`; **awaiting credentialed `.11` agent** |
| RAL-798 interrupt → executor | **Partial** — discovery/claim proven 20:47Z; executor unproven until Stage A retry @ `5bcb257e` |
| RAL-800 Host surgical-apply OK | **No** — latest comment Aug 22 18:15Z; signal `20260825T212030Z` no receipt |
| RAL-793 CLAIMED + inventory | **No** — Todo; gated behind RAL-820 |
| This pod (Ooterverse override) | **Cannot land** — secrets absent; Tailscale NeedsLogin |

## Blocker order (current)

1. **RAL-800** surgical land — credentialed Mac/cloud agent or Mac Hermes curl-land
2. **Stage A** live retry on `.11` with `cos-local@5bcb257e` + preserved `DISPATCH-NOW RAL-820`
3. **RAL-820** `subject.txt` = `executed\n` + `worker_session_finalized` with `reportback_verified=true`
4. **RAL-793** CLAIMED + inventory (own execution contract required)

## Pick one path

### A — New cloud agent (preferred)

1. **Web UI only** (not mobile) → repo **`ilike4movies/hermes-mac-land`**
2. Environment: **LEGACY Hermes .11 — do not use for Ooterverse**
3. **Runtime Secrets at agent boot**: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`
4. Auto-runs **Step 1** surgical land + read-only Stage A source/live preflight (`HERMES_AUTO_STAGE_A_PREFLIGHT=1` default). Bounded Stage A activation remains manual per deployment packet (`APPROVE-RJS-LIVE-BUNDLE-1` for Stage A only; full engine bundle: `APPROVE-RJS-EXECUTION-ENGINE-LIVE-1`).

### B — Resume verified agent (or re-run land on credentialed pod)

https://cursor.com/agents/bc-458cf08d-4954-411a-978a-de2adb650e33

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
HERMES_PREFER_DIRECT_HOST=1 bash /tmp/hermes-cloud-apply/hermes-moltbot-cloud-apply-install-via-ssh.sh
# preflight auto-runs after land on credentialed agents (HERMES_AUTO_STAGE_A_PREFLIGHT=1)
# or run manually:
bash /tmp/hermes-cloud-apply/hermes-stage-a-preflight.sh
# then bounded Stage A activation per deployment-packet.md @ cos-local 5bcb257e
# approval token: APPROVE-RJS-LIVE-BUNDLE-1
```

### C — Mac Hermes

```bash
gh auth login
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
```

## Success markers (in order)

1. `INFO: HERMES_PREFER_DIRECT_HOST=1 — skipping jump`
2. `== fetching moltbot tip via gh tarball (caller) ==`
3. `== uploading tip tarball to ilike4@…`
4. `OK INTERRUPT_LABEL hermes-now`
5. `post-apply canary focus: RAL-820`
6. RAL-800 → **Host surgical-apply OK**
7. RAL-820 → `subject.txt` = `executed` + `worker_session_finalized` with `reportback_verified=true`
8. RAL-793 → Hermes **CLAIMED** + inventory

## Do not use

- Slack rockets as primary wake path
- Ooterverse override env for Hermes deploy (no secrets at boot)
- `hermes-now` on RAL-793 until RAL-820 proves interrupt + contract exists
- Merging `moltbot` PR #76 while linked to RAL-820/RAL-793 in Linear
- Stage A with pre-#86 `cos-local@054895ab` alone
- `git reset --hard` on `/opt/moltbot`

## Repos

| Repo | Role |
|------|------|
| `ilike4movies/hermes-mac-land` | Public Mac/cloud land scripts (this repo) |
| `ilike4movies/moltbot` | Private dispatcher stack |
| `ilike4movies/hermes-agent-cos` | RAL-798 control-loop adapter (Stage A on `.11`) |
