# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` (`four-openclaw`) **with inventory progress**. GitHub `main` alone is not sufficient.

**Updated:** 2026-08-25T22:20Z

## ⚠️ Ooterverse / mobile override agents cannot land

Agents on `Ooterverse-Saturns-Quest` (including mobile override) **do not receive** `TS_AUTHKEY` / `HERMES_HOST_SSH_PRIVATE_KEY` at boot. Tailscale stays `NeedsLogin`; no surgical land or Stage A is possible from those pods. Use path A, B, or C below on `hermes-mac-land` with **LEGACY Hermes .11** secrets.

## ⚠️ Do not link deploy/operator PRs to open canary issues

Linear auto-Dones linked issues on PR merge **without** live `.11` proof.

| Issue | Risk |
|-------|------|
| **RAL-800** | PR #11 + #12 (22:11Z, 22:15Z) falsely closed surgical-land gate — reopened twice |
| **RAL-820 / RAL-793** | `moltbot` PR #76 linked — do not merge until detached |
| **RAL-798** | Root interrupt ticket — keep PRs unlinked during prove-out |

Link operator/doc PRs to **RAL-799** or leave unlinked. Live proof comments belong on the canary tickets after execution.

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

**21:38Z:** PR #86 merged to `cos-local`. **Stage A source gate cleared.**

**21:54Z:** `hermes-mac-land` PR [#8](https://github.com/ilike4movies/hermes-mac-land/pull/8) merged — cloud land auto-chains read-only Stage A preflight after successful surgical apply.

**22:05Z:** `hermes-mac-land` PR [#10](https://github.com/ilike4movies/hermes-mac-land/pull/10) merged — source+live Stage A preflight chain.

**22:11Z:** PR [#11](https://github.com/ilike4movies/hermes-mac-land/pull/11) merged — credentialed resume-land one-liner.

**22:15Z:** PR [#12](https://github.com/ilike4movies/hermes-mac-land/pull/12) merged — Linear auto-Done warning (do not link operator PRs to RAL-800).

## Live proof timeline (Aug 25)

| Time (UTC) | Event | Result |
|------------|-------|--------|
| 20:47Z | Stage A @ pre-#86 bundle | Interrupt/claim **passed**; worker failed `ral733-core-worker-finalizer-missing`; rolled back |
| 22:15Z | `DISPATCH-NOW RAL-820` | **CLAIMED** (`run 3890599`) — interrupt path alive |
| 22:16–22:19Z | Stage A @ `5bcb257e` retry | Recovery prepare **passed** (`recovered_claim_pending_host_execution`); host execution blocked by thermal gate **CPU 99.0°C ≥ 85.0°C**; zero model calls; `subject.txt` still `pending`; exact rollback verified |

**22:19Z disposition:** Environmental fail-closed, not a new source defect. Retry Stage A only after fresh thermal readback is below 85°C. RAL-820 completion gate (`subject.txt` = `executed\n`) remains open.

## Current live state (readback 22:20Z)

| Check | Status |
|-------|--------|
| RAL-820 successor canary (`subject.txt` → `executed`) | **Open** — Stage A reached host-execution gate; thermal block at 22:19Z |
| RAL-798 interrupt → executor | **Partial** — DISPATCH-NOW→CLAIMED proven; executor blocked on thermal, not finalizer |
| RAL-800 Host surgical-apply OK | **No** — no live proof since Aug 22 18:15Z |
| RAL-793 CLAIMED + inventory | **No** — Todo; gated behind RAL-820 |
| Host thermal | **Hot** — 99°C at 22:19Z; wait for cooldown before Stage A retry |
| This pod (Ooterverse override) | **Cannot land** — secrets absent; Tailscale NeedsLogin |

## Blocker order (current)

1. **Host thermal cooldown** — CPU must read below 85°C before Stage A executor retry
2. **RAL-800** surgical land — credentialed Mac/cloud agent or Mac Hermes curl-land (still unproven on tip `main`)
3. **Stage A** live retry on `.11` with `cos-local@5bcb257e` + preserved `DISPATCH-NOW RAL-820`
4. **RAL-820** `subject.txt` = `executed\n` + `worker_session_finalized` with `reportback_verified=true`
5. **RAL-793** CLAIMED + inventory (own execution contract required)

## Pick one path

### A — New cloud agent (preferred)

1. **Web UI only** (not mobile) → repo **`ilike4movies/hermes-mac-land`**
2. Environment: **LEGACY Hermes .11 — do not use for Ooterverse**
3. **Runtime Secrets at agent boot**: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`
4. Auto-runs **Step 1** surgical land + read-only Stage A source/live preflight (`HERMES_AUTO_STAGE_A_PREFLIGHT=1` default). Bounded Stage A activation remains manual per deployment packet (`APPROVE-RJS-LIVE-BUNDLE-1` for Stage A only; full engine bundle: `APPROVE-RJS-EXECUTION-ENGINE-LIVE-1`).

### B — Resume credentialed agent (one-liner)

**Requires** Runtime Secrets `TS_AUTHKEY` + `HERMES_HOST_SSH_PRIVATE_KEY` on a `hermes-mac-land` agent (LEGACY Hermes .11 env).

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-credentialed-resume-land.sh | bash
```

Chains: bootstrap → direct `.11` surgical land → source preflight → live preflight. Log: `/tmp/hermes-cloud-apply/resume-land.log`.

**Manual equivalent:**

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
HERMES_PREFER_DIRECT_HOST=1 bash /tmp/hermes-cloud-apply/hermes-moltbot-cloud-apply-install-via-ssh.sh
bash /tmp/hermes-cloud-apply/hermes-stage-a-source-preflight.sh
bash /tmp/hermes-cloud-apply/hermes-stage-a-preflight.sh
```

Then bounded Stage A activation per `deployment-packet.md` @ cos-local `5bcb257e` with preserved `DISPATCH-NOW RAL-820` comment + token `APPROVE-RJS-LIVE-BUNDLE-1` — **only after thermal readback < 85°C**.

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
7. CPU thermal < 85°C (host safety gate)
8. RAL-820 → `subject.txt` = `executed` + `worker_session_finalized` with `reportback_verified=true`
9. RAL-793 → Hermes **CLAIMED** + inventory

## Do not use

- Slack rockets as primary wake path
- Ooterverse override env for Hermes deploy (no secrets at boot)
- `hermes-now` on RAL-793 until RAL-820 proves interrupt + contract exists
- Merging `moltbot` PR #76 while linked to RAL-820/RAL-793 in Linear
- Linking operator PRs to RAL-800/RAL-820/RAL-793/RAL-798 (auto-Done without live proof)
- Stage A retry while host CPU ≥ 85°C
- Stage A with pre-#86 `cos-local@054895ab` alone
- `git reset --hard` on `/opt/moltbot`

## Repos

| Repo | Role |
|------|------|
| `ilike4movies/hermes-mac-land` | Public Mac/cloud land scripts (this repo) |
| `ilike4movies/moltbot` | Private dispatcher stack |
| `ilike4movies/hermes-agent-cos` | RAL-798 control-loop adapter (Stage A on `.11`) |
