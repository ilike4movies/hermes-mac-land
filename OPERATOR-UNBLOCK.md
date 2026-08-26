# Hermes dispatcher — operator unblock (RAL-800)

**Hard gate:** RAL-793 must show Hermes **CLAIMED** on live `.11` with inventory progress.

**Updated:** 2026-08-26T08:10Z

## Live now — zero-model canary VERIFIED

| Item | Evidence |
|------|----------|
| Apply | PR #120 live apply; receipt `/tmp/ral733-pr120-deploy.ygL7hT/packet/apply-receipt.json` |
| Canary | Run `20260826T080254019867Z-1097131`, `req-c8a22ccbc2504e6b`, `VERIFIED_COMPLETE`, **0** model/API/tool calls |
| Replay | Cycle `20260826T080342086747Z-1099734` = `healthy_noop`, no duplicate |
| Timer | `cos-hermes-orchestrator.timer` **enabled + active** (5m) |

### Follow-ups (source, before RAL-798 Done)

1. **Mode preserve** — apply restored 0755 after three scripts dropped to 664 (systemd 203/EXEC)
2. **Comment pagination** — poll only first 20 comments; freshest `DISPATCH-NOW` can hide (label path worked)
3. **PR #115** — state/label direction binding still draft

### Critical path

1. Mode + comment-pagination source fixes → natural scheduled cycle readback
2. PR #115 install if still needed for admin-state reopen
3. Ralph accept/close RAL-820 → dispatch RAL-793
4. RAL-800 tip-main land (proves RAL-634)

## Gate table

| Gate | Status |
|------|--------|
| RAL-798 interrupt → executor | **PROVED** (397968 + 1097131 zero-model) |
| RAL-820 canary + quiet replay | **PROVED** — acceptance pending; mode/pagination follow-ups |
| RAL-800 tip-main land | **OPEN** |
| RAL-793 CLAIMED | **NO** |
| moltbot [PR #76](https://github.com/ilike4movies/moltbot/pull/76) | **DRAFT** — do not merge |

## ⚠️ Hermes work belongs in hermes-mac-land / hermes-agent-cos / moltbot — not Ooterverse
