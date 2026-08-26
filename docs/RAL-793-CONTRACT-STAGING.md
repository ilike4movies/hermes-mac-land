# RAL-793 execution contract staging (live `.11`)

**Do not** post `DISPATCH-NOW RAL-793` or apply `hermes-now` until a reviewed
contract is pinned in the live registry. Natural cycles correctly skip
RAL-793 when `contract-unresolved`.

**Do not** attach/merge GitHub PRs to RAL-793/798/800 that auto-Done canaries.

## Automated install (preferred)

Credentialed Mac/cloud agent with SSH to `.11`:

```bash
curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/shared-scripts/hermes-ral793-contract-install.sh | bash -s -- --post-linear
```

Options:
- `--dry-run` — preflight only, no registry mutation
- `--post-linear` — post install/readback comment to RAL-793

The install script also auto-updates registry SHA pins in crontab/launchers when
the old pin appears exactly once (fail-closed on ambiguous counts).

## Why this exists

RAL-820 proved Linear interrupt → executor. RAL-800/799 closed the GitHub→host
apply gap @ 20:22Z. RAL-798 Done criteria still require RAL-793 **CLAIMED** +
inventory under its **own** contract (not the subject.txt canary).

Prior CLAIMED @ 12:55Z (run `1545251`) produced WORK-PACKET-DONE only —
**not** objective closure. Contract was not pinned; inventory evidence missing.

## Live registry location (read first)

On `.11` (credentialed SSH / Mac land only):

```bash
REG=/opt/moltbot/data/cos-hermes/execution-contract-registry.json
sha256sum "$REG"
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p.get("schema"), sorted((p.get("contracts") or {}).keys()))' "$REG"
```

Schema must be `cos.linear.execution_contract_registry.v1`.

SHA pin updates are handled by the install script when registry hash changes.

## Phase-1 contract (inventory only)

Scope matches RAL-793 ticket slice 1–2 + evidence write. **Out of scope:**
YouTube upload, OAuth, dashboard restart, asset deletion, EP produce/render
mutation beyond read-only inventory.

The install script creates evidence home if missing:
`/opt/moltbot/data/cos-hermes/canaries/ral793-inventory/evidence/RAL-793-inventory.md`

Draft registry entry key `RAL-793` (staged by cos-local #125 stager):

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

## Apply procedure (surgical)

1. Run `hermes-ral793-contract-install.sh --post-linear` (backs up registry, stages contract, updates SHA pins).
2. Readback: registry contains `RAL-793`, comment posted to RAL-793.
3. Only then interrupt:

```text
DISPATCH-NOW RAL-793
```

or label `hermes-now` on RAL-793.

4. Expect Hermes **CLAIMED** within one ~5m timer tick + run dir under
   dispatcher runs. Post inventory evidence on RAL-793.

## Rollback

Restore backed-up registry from `/opt/moltbot/data/cos-hermes/deploy-backups/`;
verify SHA-256; leave RAL-793 In Progress if claim did not start.

## After CLAIMED

- Continue inventory → EP04 dry-run under revised contract (still no upload).
- Parallel: `hermes-ral634-starvation-verify.sh --post-linear` for RAL-634 prove-out.
