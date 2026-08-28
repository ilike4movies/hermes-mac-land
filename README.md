# Hermes Mac land (public bootstrap)

**Operator unblock (RAL-800 / live `.11` land):** [OPERATOR-UNBLOCK.md](OPERATOR-UNBLOCK.md) — pick cloud agent, verified agent, Mac path, or GitHub Actions.

> **Wrong repo?** Do not run Hermes land from Ooterverse-Saturns-Quest. Use **`ilike4movies/hermes-mac-land`** + env **LEGACY Hermes .11** + Runtime Secrets at boot. **Ooterverse subagents cannot run downstream** — they inherit the wrong env.

## Current critical path (2026-08-28)

**Upstream gates Done:** RAL-820 interrupt, RAL-800 tip-main land, RAL-799 live canary+drift, RAL-634 starvation + transition dedupe (#103 live @ 03:35Z).

**Sole blocker:** Media Studio canary contract + inventory evidence (run `2954673` CLAIMED @ 23:25Z 2026-08-26 but stalled ~27h+). **Do not re-land** unless tip refresh is needed.

**Parallel (not media-studio canary):** moltbot [#110](https://github.com/ilike4movies/moltbot/pull/110) WIP-park material-evidence **MERGED** to `main` @ `a535cb7` / tip `c753da8a` — confirm `.11` apply (RAL-799 auto-apply or `HERMES_AUTO_STACK_APPLY=1`); keep RAL-798 In Progress until host readback.

### Fastest now — stalled media-studio canary run (Mac)

1. Confirm **`LINEAR_API_KEY` in `~/.hermes/.env`** (required post-#59 — downstream fails closed without it; ONE-SHOT fail-fast before SSH)
2. Download **fresh** [`HERMES-ONE-SHOT-UNBLOCK.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ONE-SHOT-UNBLOCK.command)
3. **Right-click → Open** on Mac Hermes (not double-click — Gatekeeper)

**Prefer ONE-SHOT:** tries **STALL** downstream first (SSH/Tailscale to `.11`); on fail auto-runs **ENABLE-DOWNSTREAM-ACTIONS** (install workflow + `gh workflow run`). Better than picking between STALL vs ENABLE yourself.

Pins run `20260826T232521106484Z-2954673`. STALL path: inspect → contract install → (stack-apply **skipped** by default; `.11` already at `6ce15a8`) → **two** `DISPATCH-NOW` passes (~90s; SLA-stale CLAIM recovery) → RAL-634 verify → inventory wait (~3 min). Defaults `HERMES_AUTO_STACK_APPLY=0` + `HERMES_STALL_RECOVERY=1` + `HERMES_WAIT_INVENTORY=1` (#42/#44/#52/#59/#62/#65/#70).

**Runtime ~3–5 min (STALL) or ~5–10 min (Actions fallback).** Watch [GitHub issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) for `## Downstream STARTED` → `DONE`.

**Secondary — STALL only** (when Tailscale+SSH already known-good):

1. Download [`HERMES-DOWNSTREAM-RAL793-STALL.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command)
2. **Right-click → Open** on Mac Hermes

### Or GitHub Actions (durable; one-time enable)

Avoids Mac click after secrets are set. See [docs/CI-DOWNSTREAM-STALL.md](docs/CI-DOWNSTREAM-STALL.md). Prefer ONE-SHOT (Phase 2 fallback), or ENABLE launcher below.

**Mac enable** (uses local `gh`, which can have `workflow` scope cloud APIs lack):

1. Download [`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-ENABLE-DOWNSTREAM-ACTIONS.command) (or use ONE-SHOT which falls back here)
2. **Right-click → Open** — installs `.github/workflows/downstream-stall.yml` + runs the workflow
3. If scope error: `gh auth refresh -h github.com -s workflow` then re-open
4. Action secrets must exist: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`, `LINEAR_API_KEY`

**Or web UI:**

1. Copy [`ci/downstream-stall.yml`](ci/downstream-stall.yml) → `.github/workflows/downstream-stall.yml` on `main`
2. Add Action secrets (same three)
3. **Actions → Downstream stall recovery → Run workflow** (or `gh workflow run downstream-stall.yml`)

### Or downstream-only (generic)

1. Download **fresh** `HERMES-DOWNSTREAM-ONLY.command` from this repo
2. **Right-click → Open** on Mac Hermes

Or terminal:

```bash
# Simplified post-#47 (auto-pins stall run + stack-apply=0 + stall_recovery=1):
HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash

# Explicit run pin (alternate):
HERMES_RUN_ID=20260826T232521106484Z-2954673 HERMES_AUTO_SURGICAL_LAND=0 \
  curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-dispatcher-downstream.sh | bash
```

**Chain:** run inspect → contract install + readback → (stack-apply optional; stall defaults skip) → auto `DISPATCH-NOW` ×2 when stall recovery (Linear interrupt; no Slack rocket) → RAL-634 verify PASS/FAIL → inventory wait.

**Pass criteria:** contract readback + `evidence/RAL-793-inventory.md` on the media-studio canary ticket. **Not** WORK-PACKET-DONE alone.

**Machine inbox:** [GitHub issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) — expect `## Downstream STARTED` → `## Downstream DONE`.

**Linear hygiene:** do not attach GitHub PRs to open canary tickets; do not put open canary ticket IDs in PR titles.

## macOS Gatekeeper (read this first)

Double-clicking a downloaded `.command` file may show **"could not verify … is free of malware"** before the script runs. That is normal for GitHub downloads.

**Do not click Move to Trash.** Pick one:

1. **Terminal (recommended):**
   ```bash
   gh auth login   # required: Mac uploads private moltbot tip via gh tarball
   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
   ```
2. **Right-click → Open** on `HERMES-DIAGNOSE-THEN-LAND.command`, then confirm **Open** again.
3. **Unquarantine then open:**
   ```bash
   xattr -d com.apple.quarantine ~/Downloads/HERMES-DIAGNOSE-THEN-LAND.command
   open ~/Downloads/HERMES-DIAGNOSE-THEN-LAND.command
   ```

---

`HERMES-DIAGNOSE-THEN-LAND.command` prefers a **single GitHub archive tarball** (co-located diag + via-ssh), then falls back to per-file raw/CDN. Default pin: **`main`** (override with `HERMES_MAC_LAND_PIN` for a frozen SHA).

## Full diagnose + land (when tip refresh needed)

1. Open: https://github.com/ilike4movies/hermes-mac-land
2. Download a **fresh** `HERMES-DIAGNOSE-THEN-LAND.command` (default pin `main`)
3. **Right-click → Open** on Mac Hermes (Tailscale up or home LAN to `.11`)

Runs diagnostic first (Desktop + clipboard + Linear/GitHub), then land.

**Land path (tip `main`):**
- **Direct `.11` by default** (`HERMES_PREFER_DIRECT_HOST=1`) — skips jump grok-cos-1
- Mac fetches private `moltbot` tip via **`gh api …/tarball/main`** and `tar | ssh` uploads to `.11` (no private git clone on host)
- Fallback: host tries git clone if `gh` unavailable

Diag also opens **RAL-800** + [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) in the browser so you can paste Desktop diag if remote post fails.

## Or land only

1. Download a **fresh** `HERMES-UNBLOCK-APPLY.command`
2. **Right-click → Open** on **Mac Hermes** (Tailscale or LAN to `.11`)

## If land hung / silent — diagnose only

1. Download **fresh** `HERMES-DIAGNOSE.command`
2. **Right-click → Open** on Mac Hermes

Surfaces status even **without** `LINEAR_API_KEY`:
- `~/Desktop/HERMES-MAC-LAND-DIAG.txt` (+ clipboard + TextEdit)
- Opens Linear **RAL-800** + GitHub issue #1 for paste
- Linear comment if `~/.hermes/.env` has the key
- GitHub [issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) if `gh` logged in **or** `GH_TOKEN` / `HERMES_STATUS_GITHUB_TOKEN` in `~/.hermes/.env`
- If still silent: opens a **Mail draft** to `ilike4@gmail.com` with the DIAG attached (click Send once)

## Terminal land (default main; copy from Linear/Notion, not Gmail)

```bash
gh auth login
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash
```

jsDelivr fallback (can lag):

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ilike4movies/hermes-mac-land@main/hermes-mac-land.sh | bash
```

## Terminal diagnose

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-moltbot-mac-land-diag.sh | bash
```

## Needs on Mac

- Tailscale up **or** home LAN SSH to `.11` (`192.168.1.11` / `100.105.194.96`)
- **`gh auth login`** — Mac uploads private `moltbot` tip tarball to `.11` (read access to `ilike4movies/moltbot`)
- SSH BatchMode to `.11` (jump `grok-cos-1` optional; land skips jump by default)

In `~/.hermes/.env`:
- **`LINEAR_API_KEY`** — **required** for downstream `DISPATCH-NOW` post-#59 (fail-closed); also STARTED/FAILED/DIAGNOSTIC on RAL-800
- `HERMES_HOST_SSH_PRIVATE_KEY` — PEM for BatchMode SSH to `.11` (land auto-loads if unset in shell)
- `GH_TOKEN` / `HERMES_STATUS_GITHUB_TOKEN` — optional; posts machine status to GitHub issue #1

**After 2026-08-22 host-key install:** re-run land even if an earlier attempt failed pre-key.

## Expect

### After downstream-only (current path)

1. Media-studio canary run inspect summary on Linear (when stalled)
2. Contract install readback on Linear
3. Governed stack-apply (skipped by stall defaults unless mirror drifted)
4. Auto `DISPATCH-NOW` posted ×2 when stall recovery (Linear interrupt — no Slack rocket; **requires LINEAR_API_KEY**)
5. Hermes progress under pinned contract + `evidence/RAL-793-inventory.md`
6. RAL-634 verify PASS receipt (downstream step; RAL-634 already Done separately)
7. Inventory wait (~3 min) until evidence is real
8. GitHub #1 `## Downstream STARTED` → `## Downstream DONE` or `PARTIAL`

### After full land (tip refresh)

Terminal output markers:
1. `INFO: HERMES_PREFER_DIRECT_HOST=1 — skipping jump`
2. `== fetching moltbot tip via gh tarball (caller) ==`
3. `== uploading tip tarball to ilike4@…`
4. `OK INTERRUPT_LABEL hermes-now`
5. `post-apply canary focus: RAL-820` (not media-studio canary)

Then: RAL-800 `Host surgical-apply OK` → RAL-820 canary → downstream gates (contract + stack-apply + dispatch + RAL-634 verify).

No Slack rockets.

## Cloud Cursor agents (RAL-800)

Hermes deployment scripts live in **this repo** and `ilike4movies/moltbot` — not in Ooterverse-Saturns-Quest (game-only).

**Runtime Secrets must be attached at agent boot.** Internal cloud subagents, mobile-started agents, and draft override environment builds do **not** receive `TS_AUTHKEY` or `HERMES_HOST_SSH_PRIVATE_KEY` mid-session. **Do not spawn Hermes subagents from Ooterverse** — they inherit the wrong repo/env.

**Cursor routing (2026-08-24):** Hermes deployment / RAL-800 / `.11` / Tailscale / surgical-apply work belongs on **`ilike4movies/hermes-mac-land`** with the saved environment **LEGACY Hermes .11 — do not use for Ooterverse**, never the Ooterverse game environment.

For downstream-only boot on a credentialed cloud agent: set `HERMES_AUTO_SURGICAL_LAND=0` only (`HERMES_AUTO_DOWNSTREAM=1` default). Since **#36**, stall run auto-pins when unset. Since **#44**, also defaults `HERMES_AUTO_STACK_APPLY=0` + `HERMES_STALL_RECOVERY=1` (parity with stall launcher). Since **#47** (2026-08-27): bare `curl | bash` downstream applies the same stall defaults when run ID matches or is auto-pinned. Since **#52**: stall recovery posts two `DISPATCH-NOW` passes (~90s) so SLA-stale CLAIMs reopen after fail. Since **#59**: fail-closed if Linear key missing + inventory wait (~3 min). Since **#62**: Right-click → Open wording in downstream preflight + stall `.command` header. Since **#65**: STALL.command fail-fast LINEAR preflight before SSH. Since **#68**: copyable Actions workflow under `ci/`. Mac enable launcher installs it under `.github/workflows/` via local `gh`. Since **#70**: ONE-SHOT unblock launcher (`HERMES-ONE-SHOT-UNBLOCK.command`) tries STALL then ENABLE-ACTIONS fallback.

`hermes-dispatcher-downstream.sh` fail-fast preflights missing secrets / wrong repo in <1s (`60cf813`) — see [OPERATOR-UNBLOCK.md](OPERATOR-UNBLOCK.md).

See **[OPERATOR-UNBLOCK.md](OPERATOR-UNBLOCK.md)** for the full checklist and pitfalls.
