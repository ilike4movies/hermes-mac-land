# Hermes Mac land (public bootstrap)

**Operator unblock (RAL-800 / live `.11` land):** [OPERATOR-UNBLOCK.md](OPERATOR-UNBLOCK.md) — pick cloud agent, verified agent, or Mac path.

> **Wrong repo?** Do not run Hermes land from Ooterverse-Saturns-Quest. Use **`ilike4movies/hermes-mac-land`** + env **LEGACY Hermes .11** + Runtime Secrets at boot. **Ooterverse subagents cannot run downstream** — they inherit the wrong env.

## Current critical path (2026-08-27)

**Upstream gates Done:** RAL-820 interrupt, RAL-800 tip-main land, RAL-799 live canary+drift, RAL-634 starvation + transition dedupe (#103 live @ 03:35Z).

**Sole blocker:** RAL-793 contract + inventory evidence (run `2954673` CLAIMED @ 23:25Z 2026-08-26 but stalled ~24h+). **Do not re-land** unless tip refresh is needed. Gmail ACTION + URGENT threads still UNREAD — Mac Right-click → Open `HERMES-DOWNSTREAM-RAL793-STALL.command`.

**Parallel (not RAL-793):** moltbot [#110](https://github.com/ilike4movies/moltbot/pull/110) WIP-park material-evidence **MERGED** to `main` @ `a535cb7` / tip `c753da8a` — confirm `.11` apply (RAL-799 auto-apply or `HERMES_AUTO_STACK_APPLY=1`); keep RAL-798 In Progress until host readback.

### Fastest now — stalled RAL-793 run (Mac)

1. Download **fresh** [`HERMES-DOWNSTREAM-RAL793-STALL.command`](https://github.com/ilike4movies/hermes-mac-land/raw/main/HERMES-DOWNSTREAM-RAL793-STALL.command)
2. **Right-click → Open** on Mac Hermes (Tailscale or LAN to `.11`)

Pins run `20260826T232521106484Z-2954673` and runs: inspect → contract install → (stack-apply **skipped** by default; `.11` already at `6ce15a8`) → **two** `DISPATCH-NOW` passes (~90s; SLA-stale CLAIM recovery) → RAL-634 verify. Defaults `HERMES_AUTO_STACK_APPLY=0` + `HERMES_STALL_RECOVERY=1` (#42/#44/#52).

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

**Chain:** RAL-793 run inspect → contract install + readback → (stack-apply optional; stall defaults skip) → auto `DISPATCH-NOW` ×2 when stall recovery (Linear interrupt; no Slack rocket) → RAL-634 verify PASS/FAIL.

**Pass criteria:** contract readback + `evidence/RAL-793-inventory.md` on RAL-793. **Not** WORK-PACKET-DONE alone.

**Machine inbox:** [GitHub issue #1](https://github.com/ilike4movies/hermes-mac-land/issues/1) — expect `## Downstream STARTED` → `## Downstream DONE`.

**Linear hygiene:** do not attach GitHub PRs to open canary tickets; do not put `RAL-793` in PR titles.

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

Optional in `~/.hermes/.env`:
- `LINEAR_API_KEY` — STARTED/FAILED/DIAGNOSTIC on RAL-800
- `HERMES_HOST_SSH_PRIVATE_KEY` — PEM for BatchMode SSH to `.11` (land auto-loads if unset in shell)

**After 2026-08-22 host-key install:** re-run land even if an earlier attempt failed pre-key.

## Expect

### After downstream-only (current path)

1. RAL-793 run inspect summary on Linear (when stalled)
2. RAL-793 contract install readback on Linear
3. Governed stack-apply (skipped by stall defaults unless mirror drifted)
4. Auto `DISPATCH-NOW RAL-793` posted (Linear interrupt — no Slack rocket)
5. Hermes progress under pinned contract + `evidence/RAL-793-inventory.md`
6. RAL-634 verify PASS receipt (downstream step; RAL-634 already Done separately)
7. GitHub #1 `## Downstream STARTED` → `## Downstream DONE`

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

For downstream-only boot on a credentialed cloud agent: set `HERMES_AUTO_SURGICAL_LAND=0` only (`HERMES_AUTO_DOWNSTREAM=1` default). Since **#36**, `HERMES_RUN_ID` auto-pins stall run `20260826T232521106484Z-2954673` when unset. Since **#44**, also defaults `HERMES_AUTO_STACK_APPLY=0` + `HERMES_STALL_RECOVERY=1` (parity with stall launcher). Since **#47** (2026-08-27): bare `curl | bash` downstream applies the same stall defaults when run ID matches or is auto-pinned. Since **#52**: stall recovery posts two `DISPATCH-NOW` passes (~90s) so SLA-stale CLAIMs reopen after fail.

`hermes-dispatcher-downstream.sh` fail-fast preflights missing secrets / wrong repo in <1s (`60cf813`) — see [OPERATOR-UNBLOCK.md](OPERATOR-UNBLOCK.md).

See **[OPERATOR-UNBLOCK.md](OPERATOR-UNBLOCK.md)** for the full checklist and pitfalls.
