# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` (`four-openclaw`) **with inventory progress**. GitHub `main` alone is not sufficient.

**Updated:** 2026-08-25T21:37Z

## ⚠️ moltbot PR #76 — do not merge yet

[`moltbot` PR #76](https://github.com/ilike4movies/moltbot/pull/76) is **linked in Linear to RAL-820 and RAL-793**. Merging while attached may auto-Done those issues before live `.11` proof.

Land scripts on `hermes-mac-land` `main` already export `HERMES_POST_APPLY_CANARY=RAL-820` — merge PR #76 only after detaching from canary issues or after canary proof.

## Two live steps (do not conflate)

| Step | Ticket | What it does | Repo | Auto on cloud boot? |
|------|--------|--------------|------|-------------------|
| **1 — Surgical land** | RAL-800 | Lands `moltbot` tip on `/opt/moltbot` (interrupt label, WIP park, apply watch, drift) | `moltbot` via this repo | **Yes** — `hermes-cloud-agent-start.sh` |
| **2 — Stage A canary** | RAL-798 / RAL-820 | Installs `hermes-agent-cos` control-loop adapter + runs bounded RAL-820 canary (`subject.txt` → `executed`) | `hermes-agent-cos` `cos-local` @ merged **PR #86** | **No** — separate bounded activation on `.11` |

Surgical land alone does **not** deploy PR #82+#83 comment-first interrupt discovery. Stage A is required for `DISPATCH-NOW` without `hermes-now` and for the RAL-820 fixture proof.

After Step 1 succeeds, a credentialed agent on `.11` must run Stage A per `hermes-agent-cos` `ops/ral798-control-loop/deployment-packet.md`.

## RAL-798 source bundle

### Merged (interrupt + minimal finalizer)

| PR | Merge | Fix |
|----|-------|-----|
| [#82](https://github.com/ilike4movies/hermes-agent-cos/pull/82) | `cef81c9` | `DISPATCH-NOW` discoverable without `hermes-now`; fresh comment interrupts rank before standing labels |
| [#83](https://github.com/ilike4movies/hermes-agent-cos/pull/83) | `5e77535` | Fresh interrupt with different dedupe may create new request after terminal FAILED |
| [#84](https://github.com/ilike4movies/hermes-agent-cos/pull/84) | `cbb31dba` | Minimal `finalize_worker_session_usage` — callable but **insufficient** for RAL-733 acceptance |
| [#85](https://github.com/ilike4movies/hermes-agent-cos/pull/85) | `054895ab` | Bundle manifest guard hash refresh for post-#84 preflight |

### Pending (Stage A blocker)

| PR | Status | Fix |
|----|--------|-----|
| [#86](https://github.com/ilike4movies/hermes-agent-cos/pull/86) | **Ready for review** — head `95e39044` on `cos-local@054895ab`; source review PASS 21:34Z; CI pending | Identity-bound WAL finalizer + durable `reportback_verified=true` |

**21:23Z RAL-798 receipt:** Stage A remains blocked on **RAL-733 worker-finalizer acceptance**, not on Ralph. PR #84 does not reconcile identity-bound middleware WAL usage. **No live Stage A retry** until merged PR #86 passes independent review.

**20:47Z live proof (PR #82+#83):** interrupt/discovery/claim **passed**; worker failed `ral733-core-worker-finalizer-missing`; rolled back 20:49Z. Host restored to healthy preimage `2cb904b8…`; timer active/enabled. Preserved `DISPATCH-NOW RAL-820` comment remains on ticket.

## Current live state (readback 21:33Z)

| Check | Status |
|-------|--------|
| RAL-820 successor canary (`subject.txt` → `executed`) | **Open** — rolled back 20:49Z; retry **prohibited** until PR #86 |
| RAL-798 interrupt → executor | **Partial** — discovery/claim proven 20:47Z; executor blocked on WAL finalizer |
| RAL-800 Host surgical-apply OK | **No** — latest comment Aug 22; signal `20260825T212030Z` produced no receipt |
| RAL-793 CLAIMED + inventory | **No** — Todo; gated behind RAL-820 + own contract |

**Important:** Brief RAL-793 CLAIMED at 20:14–20:15Z was an RAL-798 Stage A accident. No executor ran. Do not treat as canary success.

## Blocker order (current)

1. **PR #86** merge + independent review (identity-bound WAL finalizer)
2. **RAL-800** surgical land — credentialed Mac/cloud agent or Mac Hermes curl-land
3. **Stage A** live retry on `.11` with merged PR #86 + preserved `DISPATCH-NOW RAL-820`
4. **RAL-820** `subject.txt` = `executed\n` + `worker_session_finalized` with `reportback_verified=true`
5. **RAL-793** CLAIMED + inventory (own execution contract required)

## Pick one path

### A — New cloud agent (preferred)

1. **Web UI only** (not mobile) → repo **`ilike4movies/hermes-mac-land`**
2. Environment: **LEGACY Hermes .11 — do not use for Ooterverse**
3. **Runtime Secrets at agent boot** (not mid-session): `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`
4. `.cursor/environment.json` on `main` auto-runs **Step 1** surgical land when secrets present
5. Same agent runs **Step 2** Stage A on `.11` per deployment packet @ merged PR #86

**Pitfalls:** Mobile cloud agents and Ooterverse override envs do **not** get Hermes secrets at boot.

### B — Resume verified agent

https://cursor.com/agents/bc-458cf08d-4954-411a-978a-de2adb650e33

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
HERMES_PREFER_DIRECT_HOST=1 bash /tmp/hermes-cloud-apply/hermes-moltbot-cloud-apply-install-via-ssh.sh
# then Stage A per hermes-agent-cos deployment packet @ merged PR #86
```

Credentials verified 2026-08-22 17:36Z. Surgical land + Stage A were **not** completed in that session.

### C — Mac Hermes (home LAN / Tailscale)

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
8. RAL-793 → Hermes **CLAIMED** + inventory (only after RAL-820 + own contract)

## Do not use

- Slack rockets as primary wake path
- Ooterverse-Saturns-Quest repo/env for Hermes deploy
- `hermes-now` on RAL-793 until RAL-820 proves interrupt + contract exists
- Internal cloud subagents without secrets at boot
- Merging `moltbot` PR #76 while linked to RAL-820/RAL-793 in Linear
- Stage A retry with `cos-local@054895ab` alone — PR #84 is insufficient; needs **PR #86**
- `git reset --hard` on `/opt/moltbot`
- Treating surgical land success as RAL-798 Done (Stage A still required)

## Repos

| Repo | Role |
|------|------|
| `ilike4movies/hermes-mac-land` | Public Mac/cloud land scripts (this repo) |
| `ilike4movies/moltbot` | Private dispatcher stack (cos-linear-dispatcher, surgical-apply) |
| `ilike4movies/hermes-agent-cos` | RAL-798 control-loop adapter (Stage A on `.11`) |
