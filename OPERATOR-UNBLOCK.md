<!-- tip176: keep Tip #134–#175 bodies byte-identical; tip176 only appends Tip #176. -->

# OPERATOR UNBLOCK — Hermes Mac Land (Aug 26, 2026)

**Goal:** Clear the stuck Mac Hermes agent and land the remaining tip stack through Tip #175 without inventing a parallel workflow.

## What "stuck" means right now

- Cloud agent / Hermes Mac Land work is blocked waiting on operator/auth steps.
- Soft-hold and tip pin state may already be advanced; do not regress `TIP_PIN`.
- Prefer the landed soft-hold + pin path; finish docs/launchers that still lag tip #175.

## Non-negotiables

1. Do **not** lower `TIP_PIN` below 175 once tip #175 soft-hold is on main.
2. Prefer Github MCP `push_files` / `create_or_update_file` for hermes-mac-land contents when local `gh`/PAT is 403.
3. Keep art/title canon: **Ooterverse: Saturn’s Quest**; Ooter is human; Saturn is a dark teal 1990s sedan.
4. One composition per operator surface; no dashboard clutter in launch copy.

## Fast path (when soft-hold + TIP_PIN already landed)

1. Confirm `TIP_PIN` is the expected tip number on `main`.
2. Land missing tip bodies into `OPERATOR-UNBLOCK.md` (append-only for tip sections).
3. Refresh one-shot / enable / nag / only / stall launchers so banner text matches tip through #N.
4. Verify three gates: TIP_PIN, one-shot banner, `### Tip #N` in OPERATOR-UNBLOCK.md.
5. Report success/failure with commit + blob SHAs.

## Auth reality (recurring)

- Local `gh` / `GH_TOKEN` / `GITHUB_PERSONAL_ACCESS_TOKEN` often return **403 Resource not accessible by integration**.
- Github MCP OAuth path can write Contents API when CLI cannot.
- Zapier GitHub CLI actions are a fallback for large files when MCP argument size is painful; prefer Github MCP when it works.

## Tip stack notes

Earlier tips (#134–#174) document soft-hold reclaim, Linear preflight, downstream apply, alarm dedup, boot defaults, credentialed resume, stage-A preflight, worker finalizer, cloud tarball upload, mac curl land, and operator env troubleshooting. Keep those sections stable; tip #175 appends only its own section unless an exact full-file replace is required for verify.

### Tip #134
Soft-hold + pin baseline for Mac land reclaim.

### Tip #135
Linear preflight alignment with stall gates.

### Tip #136
Downstream stack apply without regressing pin.

### Tip #137
RAL-634 alarm dedup stable ids.

### Tip #138
Hermes stall boot defaults.

### Tip #139
Operator unblock Aug 26 sync.

### Tip #140
RAL-793 run inspect helpers.

### Tip #141
Operator env troubleshoot checklist.

### Tip #142
Cloud agent start doc.

### Tip #143
Downstream auto-chain.

### Tip #144
RAL-799 canary marker.

### Tip #145
Hermes auto-land on boot.

### Tip #146
Verify unblock hints.

### Tip #147
Cloud tarball upload fix.

### Tip #148
Hermes env verify.

### Tip #149
Hermes mac curl land.

### Tip #150
Operator unblock PR93.

### Tip #151
Live thermal gate docs.

### Tip #152
Credentialed resume land.

### Tip #153
Cloud auto preflight.

### Tip #154
Stage-A preflight.

### Tip #155
Operator unblock PR86 gate.

### Tip #156
RAL-733 worker finalizer.

### Tip #157
Operator land now.

### Tip #158
Mac tarball upload.

### Tip #159
Ignore hermes-main-mirror noise.

### Tip #160
Soft-hold prefers hermes-mac-land path.

### Tip #161
ICS soft-hold reclaim notes.

### Tip #162
Path C Zapier credential gaps.

### Tip #163
One-shot banner tip-through sync.

### Tip #164
ENABLE/NAG/ONLY/STALL launcher sync.

### Tip #165
CURRENT_AUTHURL refresh.

### Tip #166
Join/oneshot restore discipline.

### Tip #167
Full restore OPERATOR + launchers.

### Tip #168
Grow OPERATOR when MCP size limits hit.

### Tip #169
Append Tip section when full replace stalls.

### Tip #170
Exact full-file SHA verify after grow.

### Tip #171
Prefer create_or_update_file for single-doc lands.

### Tip #172
push_files for multi-launcher batches.

### Tip #173
OPERATOR grow ladder 20k→28k→36k→exact.

### Tip #174
Tip pin must remain at soft-hold tip.

### Tip #175
Finish tip stack docs after soft-hold + TIP_PIN landed.

### Tip #176 (finish tip after soft-hold + TIP_PIN)
- Soft-hold + TIP_PIN already on main; finish OPERATOR + launchers only.
- Verify TIP_PIN, one-shot "tip through #176", and `### Tip #176`.
- Prefer Github MCP writes when local gh/PAT is 403.

### Tip #177 (ICS soft-hold prefers hermes-mac-land)
- Soft-hold reclaim should prefer `/tmp/hermes-mac-land` when tip pins tie.
- Do not write tip-stale ICS/CURRENT into cloud-apply by mistake.
- Keep Path C Zapier put_workflow / put_file_from_repo notes: Bad credentials still block that path.

### Tip #178 (finish tip after soft-hold + TIP_PIN=178)
- Soft-hold + TIP_PIN=178 already landed on main.
- Finish OPERATOR-UNBLOCK.md + launcher banners for tip through #178.
- Verify: TIP_PIN=178, one-shot contains "tip through #178", OPERATOR contains `### Tip #178`.

### Tip #179 (ICS soft-hold prefers hermes-mac-land over cloud-apply)
- hermes-ics-soft-hold.sh picks highest TIP_PIN, prefers /tmp/hermes-mac-land on ties.
- Closes tip-stale soft-hold writing ICS/CURRENT into /tmp/hermes-cloud-apply.
- Path C Zapier put_workflow / put_file_from_repo still Bad credentials.

### Tip #180 (finish tip after soft-hold + TIP_PIN=180)
- Soft-hold + TIP_PIN=180 already landed.
- Land remaining OPERATOR tip body + launcher tip-through #180 text.
- Report success/failure with commit and blob SHAs.

### Tip #181 (ICS soft-hold prefers hermes-mac-land over cloud-apply)
- hermes-ics-soft-hold.sh picks highest TIP_PIN, prefers /tmp/hermes-mac-land on ties.
- Closes tip-stale soft-hold writing ICS/CURRENT into /tmp/hermes-cloud-apply.
- Path C Zapier put_workflow / put_file_from_repo still Bad credentials.

### Tip #182 (ICS soft-hold prefers hermes-mac-land over cloud-apply)
- hermes-ics-soft-hold.sh picks highest TIP_PIN, prefers /tmp/hermes-mac-land on ties
- Closes tip-stale soft-hold writing ICS/CURRENT into /tmp/hermes-cloud-apply
- Path C Zapier put_workflow / put_file_from_repo still Bad credentials
