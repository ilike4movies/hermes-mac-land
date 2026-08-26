# RAL-793 execution contract staging (live `.11`)

**Do not** post `DISPATCH-NOW RAL-793` or apply `hermes-now` until a reviewed
contract is pinned in the live registry. Natural cycles correctly skip
RAL-793 when `contract-unresolved`.

**Do not** attach/merge GitHub PRs to RAL-793/798/800 that auto-Done canaries.
Keep moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) draft.

## Why this exists

RAL-820 proved Linear interrupt → executor. RAL-798 Done criteria still require
RAL-793 **CLAIMED** + inventory under its **own** contract (not the subject.txt
canary).

## Live registry location (read first)

On `.11` (credentialed SSH / Mac land only):

```bash
REG=/opt/moltbot/data/cos-hermes/execution-contract-registry.json
# Confirm exact path via live orchestrator / cos-hermes data dir if renamed.
sha256sum "$REG"
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p.get("schema"), sorted((p.get("contracts") or {}).keys()))' "$REG"
```

Schema must be `cos.linear.execution_contract_registry.v1`.

Also pin orchestrator registry-hash if the live orchestrator embeds SHA-256 of
the registry (same pattern as `stage_ral820_registry.py`).

## Phase-1 contract (inventory only)

Scope matches RAL-793 ticket slice 1–2 + evidence write. **Out of scope:**
YouTube upload, OAuth, dashboard restart, asset deletion, EP produce/render
mutation beyond read-only inventory.

Prepare worktree / evidence home (once):

```bash
sudo mkdir -p /opt/moltbot/data/cos-hermes/canaries/ral793-inventory/evidence
sudo chown -R "$(whoami)" /opt/moltbot/data/cos-hermes/canaries/ral793-inventory
printf '%s\n' 'pending' > /opt/moltbot/data/cos-hermes/canaries/ral793-inventory/evidence/RAL-793-inventory.md
```

Draft registry entry key `RAL-793` (adjust paths after live inventory of
actual Bullpen homes):

```json
{
  "enabled": true,
  "execution_mode": "implement",
  "implementation_objective": "Inventory Bullpen Bedtime workspace and stage scripts on this host (read-only). Map EP04-EP14 artifact completeness (script/audio/images/render/metadata). Write a Markdown evidence report to evidence/RAL-793-inventory.md replacing pending with a dated inventory summary. Do not upload to YouTube, do not restart openclaw-dashboard, do not delete assets, do not perform OAuth consent.",
  "implementation_allow_paths": ["evidence/RAL-793-inventory.md"],
  "implementation_repo": "/opt/moltbot/data/cos-hermes/canaries/ral793-inventory",
  "implementation_test_command": "python3 -c \"from pathlib import Path; t=Path('evidence/RAL-793-inventory.md').read_text(); assert 'pending' not in t.splitlines()[:1]; assert 'EP04' in t; assert len(t) > 200\"",
  "implementation_test_timeout_seconds": 60,
  "implementation_worktree_root": "/tmp/cos-execution-worktrees/ral793-inventory"
}
```

Notes:

- Prefer adding `implementation_action` only when the first slice is a
  deterministic replace_text (RAL-820 style). Inventory text is usually
  model/tool-assisted — keep allow-paths narrow and red-lines explicit.
- If live consumer requires `implementation_action` for all implement
  contracts, stage a tiny deterministic starter (e.g. flip a status marker
  file) **plus** a follow-up contract revision for the real inventory write —
  do not widen allow-paths to the whole tree.
- Validate with the same field checks used for RAL-820
  (`CONSUMER_REQUIRED_IMPLEMENT_FIELDS` in
  `ops/ral798-control-loop/stage_ral820_registry.py`).

## Apply procedure (surgical)

1. Backup live registry + orchestrator bytes (timestamped under
   `/opt/moltbot/data/cos-hermes/deploy-backups/`).
2. Insert `RAL-793` contract; recompute registry SHA-256.
3. Update orchestrator embedded registry hash if present; `bash -n` check.
4. Atomic install; confirm modes `0755` on entrypoints (#121).
5. Readback: registry contains `RAL-793`, hash matches orchestrator pin.
6. Only then interrupt:

```text
DISPATCH-NOW RAL-793
```

or label `hermes-now` on RAL-793.

7. Expect Hermes **CLAIMED** within one ~5m timer tick + run dir under
   dispatcher runs. Post inventory evidence on RAL-793.

## Rollback

Restore backed-up registry + orchestrator; verify SHA-256; leave RAL-793 Todo
if claim did not start.

## After CLAIMED

- Continue inventory → EP04 dry-run under revised contract (still no upload).
- Parallel: RAL-800 tip-main land for RAL-634 prove-out.
- Keep [#115](https://github.com/ilike4movies/hermes-agent-cos/pull/115) draft
  until tip direction-binding is confirmed missing.
