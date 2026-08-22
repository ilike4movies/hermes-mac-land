# Hermes Mac land (public bootstrap)

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

## Fastest — one double-click (diagnose + land)

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

Terminal output markers:
1. `INFO: HERMES_PREFER_DIRECT_HOST=1 — skipping jump`
2. `== fetching moltbot tip via gh tarball (caller) ==`
3. `== uploading tip tarball to ilike4@…`
4. `OK INTERRUPT_LABEL hermes-now`

Then: RAL-800 `Host surgical-apply OK` → RAL-793 Hermes **CLAIMED** within ~5m.

No Slack rockets.

## Cloud Cursor agents (RAL-800)

Hermes deployment scripts live in **this repo** and `ilike4movies/moltbot` — not in Ooterverse-Saturns-Quest (game-only).

**Runtime Secrets must be attached at agent boot.** Internal cloud subagents, mobile-started agents, and draft override environment builds do **not** receive `TS_AUTHKEY` or `HERMES_HOST_SSH_PRIVATE_KEY` mid-session.

**Cursor routing (2026-08-22):** Hermes / RAL-800 / `.11` / Tailscale / surgical-apply work belongs on **`ilike4movies/hermes-mac-land`**, never the Ooterverse game environment. The secret-bearing saved environment is renamed **LEGACY Hermes .11 — do not use for Ooterverse**.

### Fastest cloud unblock (credentials already verified)

1. Open: https://cursor.com/agents/bc-458cf08d-4954-411a-978a-de2adb650e33
2. Send:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-cloud-bootstrap-waiter.sh | bash
   # when secrets present:
   HERMES_PREFER_DIRECT_HOST=1 bash /tmp/hermes-cloud-apply/hermes-moltbot-cloud-apply-install-via-ssh.sh
   ```

### New cloud agent (fresh boot)

1. Start from **web UI** (not mobile) on **`ilike4movies/hermes-mac-land`** with saved environment **LEGACY Hermes .11 — do not use for Ooterverse**
2. Runtime Secrets: `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY` (jump key optional)
3. Build: `bld-20260822-2a0b84ab` or newer, or use committed `.cursor/environment.json` on this repo (auto-start + land when secrets present)
4. Bootstrap waiter (optional): `curl -fsSL …/hermes-cloud-bootstrap-waiter.sh | bash`

### Do not use

- Slack rockets
- Internal Task subagents for surgical land (no secrets)
- Ooterverse-Saturns-Quest repo or game-only environment for Hermes work (removed in PR #9)
