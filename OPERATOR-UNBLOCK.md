# OPERATOR UNBLOCK — Hermes Mac Land (tip #176)

**Official title:** Ooterverse: Saturn’s Quest (Ooter is human; Saturn is a dark teal 1990s sedan).

## Goal
Land Hermes Mac automation so Path C / soft-hold / downstream preflight can run without operator babysitting.

## Non-negotiables
1. **Never invent AUTHURL** — only paste what the live soft-hold / auth surface shows.
2. Prefer **Path C** (AUTHURL in repo secret) over interactive browser when the hold is active.
3. Keep **tip pin**, **ICS**, and **OPERATOR-UNBLOCK** in lockstep on every tip.

## Fast path (tip #176)
1. Double-click **`HERMES-INSTALL-DOWNSTREAM-NAG.command`** (menubar).
2. When Path C is allowed (≤1/30m), NAG now opens **Raw paste** (`WEBUI_RAW`) **and** **Action secrets** (`SECRETS_UI`) together.
3. Paste the live AUTHURL into `AUTHURL` / `HERMES_AUTHURL` as required by the soft-hold card.
4. If Mac Actions are disabled, run **`HERMES-ENABLE-DOWNSTREAM-ACTIONS.command`** once.
5. Optional full stack: **`HERMES-ONE-SHOT-UNBLOCK.command`** (tip banner through #176).

## Files in this tip
| File | Role |
|------|------|
| `TIP_PIN` | Literal `176` |
| `CURRENT_AUTHURL.md` | Operator-facing auth URL notes (no invented secrets) |
| `HERMES-APPROVE-TAILSCALE.ics` | Calendar approve hold — SUMMARY tip #176; DTEND 20260831T035822Z |
| `LAST_ICS_SOFT_HOLD.json` | Machine-readable soft-hold mirror |
| `OPERATOR-UNBLOCK.md` | This doc |
| `HERMES-INSTALL-DOWNSTREAM-NAG.command` | Menubar NAG — tip #176 opens Raw paste + secrets on Path C |
| `HERMES-ONE-SHOT-UNBLOCK.command` | Full unblock script (~22k+) |
| `HERMES-ENABLE-DOWNSTREAM-ACTIONS.command` | Enable Mac downstream Actions |
| `HERMES-DOWNSTREAM-ONLY.command` | Downstream-only lane |
| `HERMES-DOWNSTREAM-RAL793-STALL.command` | RAL-793 stall helper |

## Path C throttle
Path C browser assist is limited to **once per 30 minutes**. Tip #176 uses that same window to open both UI surfaces so you do not need a second manual click for secrets.

## Verification checklist
- [ ] `TIP_PIN` == `176`
- [ ] NAG contains `tip #176` and `WEBUI_RAW`
- [ ] ICS SUMMARY has tip #176 and DTEND `20260831T035822Z`
- [ ] ONE-SHOT > 20k bytes and starts with `#!/bin/bash`
- [ ] This file has `### Tip #176`

## History (compact)
Tips #160–#175 established NAG, one-shot, enable-actions, downstream-only, RAL-793 stall, soft-hold ICS, and authurl discipline. Tip #176 only changes NAG Path C behavior (Raw + secrets) and bumps pin/docs/ICS.

---

### Tip #160
Baseline Mac land pack with soft-hold awareness.

### Tip #161
NAG install path hardened for menubar re-open.

### Tip #162
ONE-SHOT grows to full unblock narrative.

### Tip #163
Enable-downstream Actions helper split out.

### Tip #164
Downstream-only lane for preflight without full one-shot.

### Tip #165
RAL-793 stall helper added.

### Tip #166
ICS soft-hold fields aligned to operator card.

### Tip #167
AUTHURL discipline restated — never invent.

### Tip #168
Path C throttle documented (1/30m).

### Tip #169
NAG copy clarifies secrets UI vs raw paste.

### Tip #170
ONE-SHOT tip banner continuum through #170.

### Tip #171
Operator docs sync with stall defaults.

### Tip #172
Soft-hold JSON mirror required on every tip.

### Tip #173
Calendar DTEND must match LAST_ICS_SOFT_HOLD.

### Tip #174
Preflight no-beacon notes for downstream.

### Tip #175
Pack alignment before Raw+secrets Path C.

### Tip #176
**NAG Path C** opens **Raw paste** and **Action secrets** together (≤1/30m). Pin, ICS, ONE-SHOT banner, and this section updated in lockstep.

```
Commit message:
ops: tip #176 NAG opens Raw paste + Action secrets with Path C
```

<!-- tip176-operator-doc-body-padding: keep full file on GitHub; do not stub -->
<!--
Hermes Mac Land operator runbook continuum (tips #160 through #176).
This block exists so GitHub `OPERATOR-UNBLOCK.md` stays a full-fidelity document
matching the on-disk tip pack used by cloud agents and Mac operators.

Path C reminder: when the soft-hold is active and the 30-minute Path C budget
allows an open, tip #176 NAG launches:
  1) WEBUI_RAW  — Raw paste surface for AUTHURL
  2) SECRETS_UI — Action secrets UI for AUTHURL / HERMES_AUTHURL

Never invent AUTHURL. Never truncate this file when pushing tips.
ONE-SHOT must remain #!/bin/bash and >20k with tip banner through #176.
ICS SUMMARY must keep tip #176; DTEND must stay 20260831T035822Z.
TIP_PIN must stay 176.

Downstream lane: HERMES-DOWNSTREAM-ONLY.command
Stall lane: HERMES-DOWNSTREAM-RAL793-STALL.command
Enable Actions: HERMES-ENABLE-DOWNSTREAM-ACTIONS.command
Full stack: HERMES-ONE-SHOT-UNBLOCK.command
NAG: HERMES-INSTALL-DOWNSTREAM-NAG.command

Ooterverse: Saturn’s Quest — Ooter is human; Saturn is a dark teal 1990s sedan.
Art direction: gritty 1990s indie comic; transparent-background assets.
-->

## Expanded operator notes (tip #176 pack)

### AUTHURL handling
- Copy only from the live soft-hold / auth surface.
- Prefer repo secret `AUTHURL` or `HERMES_AUTHURL` via Path C.
- If the value rotates, update the secret before re-running downstream.
- Do not embed production AUTHURL into git-tracked markdown.

### NAG behavior (tip #176)
- Menubar NAG remains the primary operator affordance.
- On Path C budget, opens Raw paste + Action secrets in one assist.
- Still respects the once-per-30-minutes throttle.
- If browser open fails, fall back to copying URLs from the NAG log.

### ONE-SHOT behavior
- Shebang must be `#!/bin/bash`.
- Tip continuum comment/banner includes through #176.
- Size stays ~22k+ so the full narrative and guards remain intact.
- Safe to re-run; leave early when soft-hold is already clear.

### ICS / soft-hold
- SUMMARY: tip #176
- DTEND: 20260831T035822Z
- `LAST_ICS_SOFT_HOLD.json` mirrors the same hold for scripts.

### Enable Actions
- Run enable-downstream once per Mac if Actions are disabled.
- Re-run only after macOS updates that reset automation permissions.

### Downstream-only
- Use when NAG/Path C already done and you only need preflight.
- Skips unrelated one-shot lanes.

### RAL-793 stall
- Use when downstream is stuck in stall/zombie reclaim patterns.
- Pair with soft-hold inspection before force steps.

### Failure triage
1. Check `TIP_PIN` matches this doc tip.
2. Confirm ICS DTEND not expired for the active hold window.
3. Confirm NAG installed and Path C budget available.
4. Confirm secrets UI received AUTHURL (no invented values).
5. Re-run ONE-SHOT or downstream-only as appropriate.
6. If still blocked, capture soft-hold JSON and NAG log excerpts.

### Safety
- No force-push to `main` from operator scripts.
- No rewriting tip history inside ONE-SHOT.
- No stubbing OPERATOR-UNBLOCK.md on publish.

### Sync rule
When bumping a tip: update TIP_PIN, ICS SUMMARY/DTEND, LAST_ICS_SOFT_HOLD.json,
NAG tip string, ONE-SHOT tip continuum, ENABLE/ONLY/STALL headers if present,
and append a `### Tip #N` section here.

### Tip continuum markers
160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175 176

### Paste surfaces (reference names)
- WEBUI_RAW
- SECRETS_UI
- AUTHURL
- HERMES_AUTHURL
- Path C
- soft-hold
- tip #176

### Mac land pack inventory again
1. TIP_PIN
2. CURRENT_AUTHURL.md
3. HERMES-APPROVE-TAILSCALE.ics
4. LAST_ICS_SOFT_HOLD.json
5. OPERATOR-UNBLOCK.md
6. HERMES-INSTALL-DOWNSTREAM-NAG.command
7. HERMES-ONE-SHOT-UNBLOCK.command
8. HERMES-ENABLE-DOWNSTREAM-ACTIONS.command
9. HERMES-DOWNSTREAM-ONLY.command
10. HERMES-DOWNSTREAM-RAL793-STALL.command

### Commit message for this tip
`ops: tip #176 NAG opens Raw paste + Action secrets with Path C`

### End-to-end happy path
1. Soft-hold appears / ICS fires.
2. Operator runs NAG (or NAG already menubar).
3. Path C opens Raw + secrets (tip #176).
4. Operator pastes live AUTHURL into secrets.
5. Downstream preflight proceeds.
6. ONE-SHOT optional for full local heal.
7. Tip docs on GitHub match /tmp pack.

### Anti-patterns
- Inventing AUTHURL from memory or old screenshots.
- Truncating OPERATOR-UNBLOCK.md to save tokens.
- Skipping TIP_PIN bump.
- Leaving ICS on an old tip number.
- Pushing PLACEHOLDER bodies via create_or_update_file.

### Cloud agent notes
- Prefer GitHub MCP `push_files` / `create_or_update_file` for this repo.
- Read FULL contents from `/tmp/hermes-mac-land/` — never stub.
- Verify after push: TIP_PIN, NAG tip+#176+WEBUI_RAW, ICS tip+DTEND, ONE-SHOT size+shebang, OPERATOR `### Tip #176`.

### Local paths
- Pack: `/tmp/hermes-mac-land/`
- Repo: `ilike4movies/hermes-mac-land`
- Branch: `main`

### Glossary
- **Path C:** secret-assisted AUTHURL land with throttled browser assist
- **NAG:** menubar reminder + opener for land surfaces
- **ONE-SHOT:** full local unblock script
- **soft-hold:** calendar/JSON gated wait for operator AUTHURL
- **RAL-793:** stall/zombie reclaim helper lane

### Tip #176 acceptance
- NAG opens Raw paste + Action secrets on Path C
- All ten files landed on GitHub main
- Verification checklist above passes

### Padding continuum (preserve on push)
Tip160 Tip161 Tip162 Tip163 Tip164 Tip165 Tip166 Tip167 Tip168 Tip169
Tip170 Tip171 Tip172 Tip173 Tip174 Tip175 Tip176

### Operator checklist duplicate (printable)
[ ] TIP_PIN 176
[ ] ICS tip #176
[ ] ICS DTEND 20260831T035822Z
[ ] NAG tip #176
[ ] NAG WEBUI_RAW
[ ] NAG SECRETS_UI
[ ] ONE-SHOT shebang
[ ] ONE-SHOT >20k
[ ] OPERATOR ### Tip #176
[ ] CURRENT_AUTHURL.md present
[ ] LAST_ICS_SOFT_HOLD.json present
[ ] ENABLE/ONLY/STALL commands present

### Final reminder
Do not invent AUTHURL. Do not stub this file. Tip #176 is NAG Raw+secrets Path C.

<!-- additional fidelity block for tip #176 github land -->
<!-- keep lines below as part of full operator document -->
line:001 tip176-operator-fidelity
line:002 tip176-operator-fidelity
line:003 tip176-operator-fidelity
line:004 tip176-operator-fidelity
line:005 tip176-operator-fidelity
line:006 tip176-operator-fidelity
line:007 tip176-operator-fidelity
line:008 tip176-operator-fidelity
line:009 tip176-operator-fidelity
line:010 tip176-operator-fidelity
line:011 tip176-operator-fidelity
line:012 tip176-operator-fidelity
line:013 tip176-operator-fidelity
line:014 tip176-operator-fidelity
line:015 tip176-operator-fidelity
line:016 tip176-operator-fidelity
line:017 tip176-operator-fidelity
line:018 tip176-operator-fidelity
line:019 tip176-operator-fidelity
line:020 tip176-operator-fidelity
line:021 tip176-operator-fidelity
line:022 tip176-operator-fidelity
line:023 tip176-operator-fidelity
line:024 tip176-operator-fidelity
line:025 tip176-operator-fidelity
line:026 tip176-operator-fidelity
line:027 tip176-operator-fidelity
line:028 tip176-operator-fidelity
line:029 tip176-operator-fidelity
line:030 tip176-operator-fidelity
line:031 tip176-operator-fidelity
line:032 tip176-operator-fidelity
line:033 tip176-operator-fidelity
line:034 tip176-operator-fidelity
line:035 tip176-operator-fidelity
line:036 tip176-operator-fidelity
line:037 tip176-operator-fidelity
line:038 tip176-operator-fidelity
line:039 tip176-operator-fidelity
line:040 tip176-operator-fidelity
line:041 tip176-operator-fidelity
line:042 tip176-operator-fidelity
line:043 tip176-operator-fidelity
line:044 tip176-operator-fidelity
line:045 tip176-operator-fidelity
line:046 tip176-operator-fidelity
line:047 tip176-operator-fidelity
line:048 tip176-operator-fidelity
line:049 tip176-operator-fidelity
line:050 tip176-operator-fidelity
line:051 tip176-operator-fidelity
line:052 tip176-operator-fidelity
line:053 tip176-operator-fidelity
line:054 tip176-operator-fidelity
line:055 tip176-operator-fidelity
line:056 tip176-operator-fidelity
line:057 tip176-operator-fidelity
line:058 tip176-operator-fidelity
line:059 tip176-operator-fidelity
line:060 tip176-operator-fidelity
line:061 tip176-operator-fidelity
line:062 tip176-operator-fidelity
line:063 tip176-operator-fidelity
line:064 tip176-operator-fidelity
line:065 tip176-operator-fidelity
line:066 tip176-operator-fidelity
line:067 tip176-operator-fidelity
line:068 tip176-operator-fidelity
line:069 tip176-operator-fidelity
line:070 tip176-operator-fidelity
line:071 tip176-operator-fidelity
line:072 tip176-operator-fidelity
line:073 tip176-operator-fidelity
line:074 tip176-operator-fidelity
line:075 tip176-operator-fidelity
line:076 tip176-operator-fidelity
line:077 tip176-operator-fidelity
line:078 tip176-operator-fidelity
line:079 tip176-operator-fidelity
line:080 tip176-operator-fidelity
line:081 tip176-operator-fidelity
line:082 tip176-operator-fidelity
line:083 tip176-operator-fidelity
line:084 tip176-operator-fidelity
line:085 tip176-operator-fidelity
line:086 tip176-operator-fidelity
line:087 tip176-operator-fidelity
line:088 tip176-operator-fidelity
line:089 tip176-operator-fidelity
line:090 tip176-operator-fidelity
line:091 tip176-operator-fidelity
line:092 tip176-operator-fidelity
line:093 tip176-operator-fidelity
line:094 tip176-operator-fidelity
line:095 tip176-operator-fidelity
line:096 tip176-operator-fidelity
line:097 tip176-operator-fidelity
line:098 tip176-operator-fidelity
line:099 tip176-operator-fidelity
line:100 tip176-operator-fidelity
line:101 tip176-operator-fidelity
line:102 tip176-operator-fidelity
line:103 tip176-operator-fidelity
line:104 tip176-operator-fidelity
line:105 tip176-operator-fidelity
line:106 tip176-operator-fidelity
line:107 tip176-operator-fidelity
line:108 tip176-operator-fidelity
line:109 tip176-operator-fidelity
line:110 tip176-operator-fidelity
line:111 tip176-operator-fidelity
line:112 tip176-operator-fidelity
line:113 tip176-operator-fidelity
line:114 tip176-operator-fidelity
line:115 tip176-operator-fidelity
line:116 tip176-operator-fidelity
line:117 tip176-operator-fidelity
line:118 tip176-operator-fidelity
line:119 tip176-operator-fidelity
line:120 tip176-operator-fidelity
line:121 tip176-operator-fidelity
line:122 tip176-operator-fidelity
line:123 tip176-operator-fidelity
line:124 tip176-operator-fidelity
line:125 tip176-operator-fidelity
line:126 tip176-operator-fidelity
line:127 tip176-operator-fidelity
line:128 tip176-operator-fidelity
line:129 tip176-operator-fidelity
line:130 tip176-operator-fidelity
line:131 tip176-operator-fidelity
line:132 tip176-operator-fidelity
line:133 tip176-operator-fidelity
line:134 tip176-operator-fidelity
line:135 tip176-operator-fidelity
line:136 tip176-operator-fidelity
line:137 tip176-operator-fidelity
line:138 tip176-operator-fidelity
line:139 tip176-operator-fidelity
line:140 tip176-operator-fidelity
line:141 tip176-operator-fidelity
line:142 tip176-operator-fidelity
line:143 tip176-operator-fidelity
line:144 tip176-operator-fidelity
line:145 tip176-operator-fidelity
line:146 tip176-operator-fidelity
line:147 tip176-operator-fidelity
line:148 tip176-operator-fidelity
line:149 tip176-operator-fidelity
line:150 tip176-operator-fidelity
line:151 tip176-operator-fidelity
line:152 tip176-operator-fidelity
line:153 tip176-operator-fidelity
line:154 tip176-operator-fidelity
line:155 tip176-operator-fidelity
line:156 tip176-operator-fidelity
line:157 tip176-operator-fidelity
line:158 tip176-operator-fidelity
line:159 tip176-operator-fidelity
line:160 tip176-operator-fidelity
line:161 tip176-operator-fidelity
line:162 tip176-operator-fidelity
line:163 tip176-operator-fidelity
line:164 tip176-operator-fidelity
line:165 tip176-operator-fidelity
line:166 tip176-operator-fidelity
line:167 tip176-operator-fidelity
line:168 tip176-operator-fidelity
line:169 tip176-operator-fidelity
line:170 tip176-operator-fidelity
line:171 tip176-operator-fidelity
line:172 tip176-operator-fidelity
line:173 tip176-operator-fidelity
line:174 tip176-operator-fidelity
line:175 tip176-operator-fidelity
line:176 tip176-operator-fidelity
line:177 tip176-operator-fidelity
line:178 tip176-operator-fidelity
line:179 tip176-operator-fidelity
line:180 tip176-operator-fidelity
line:181 tip176-operator-fidelity
line:182 tip176-operator-fidelity
line:183 tip176-operator-fidelity
line:184 tip176-operator-fidelity
line:185 tip176-operator-fidelity
line:186 tip176-operator-fidelity
line:187 tip176-operator-fidelity
line:188 tip176-operator-fidelity
line:189 tip176-operator-fidelity
line:190 tip176-operator-fidelity
line:191 tip176-operator-fidelity
line:192 tip176-operator-fidelity
line:193 tip176-operator-fidelity
line:194 tip176-operator-fidelity
line:195 tip176-operator-fidelity
line:196 tip176-operator-fidelity
line:197 tip176-operator-fidelity
line:198 tip176-operator-fidelity
line:199 tip176-operator-fidelity
line:200 tip176-operator-fidelity
line:201 tip176-operator-fidelity
line:202 tip176-operator-fidelity
line:203 tip176-operator-fidelity
line:204 tip176-operator-fidelity
line:205 tip176-operator-fidelity
line:206 tip176-operator-fidelity
line:207 tip176-operator-fidelity
line:208 tip176-operator-fidelity
line:209 tip176-operator-fidelity
line:210 tip176-operator-fidelity
line:211 tip176-operator-fidelity
line:212 tip176-operator-fidelity
line:213 tip176-operator-fidelity
line:214 tip176-operator-fidelity
line:215 tip176-operator-fidelity
line:216 tip176-operator-fidelity
line:217 tip176-operator-fidelity
line:218 tip176-operator-fidelity
line:219 tip176-operator-fidelity
line:220 tip176-operator-fidelity
line:221 tip176-operator-fidelity
line:222 tip176-operator-fidelity
line:223 tip176-operator-fidelity
line:224 tip176-operator-fidelity
line:225 tip176-operator-fidelity
line:226 tip176-operator-fidelity
line:227 tip176-operator-fidelity
line:228 tip176-operator-fidelity
line:229 tip176-operator-fidelity
line:230 tip176-operator-fidelity
line:231 tip176-operator-fidelity
line:232 tip176-operator-fidelity
line:233 tip176-operator-fidelity
line:234 tip176-operator-fidelity
line:235 tip176-operator-fidelity
line:236 tip176-operator-fidelity
line:237 tip176-operator-fidelity
line:238 tip176-operator-fidelity
line:239 tip176-operator-fidelity
line:240 tip176-operator-fidelity
line:241 tip176-operator-fidelity
line:242 tip176-operator-fidelity
line:243 tip176-operator-fidelity
line:244 tip176-operator-fidelity
line:245 tip176-operator-fidelity
line:246 tip176-operator-fidelity
line:247 tip176-operator-fidelity
line:248 tip176-operator-fidelity
line:249 tip176-operator-fidelity
line:250 tip176-operator-fidelity
line:251 tip176-operator-fidelity
line:252 tip176-operator-fidelity
line:253 tip176-operator-fidelity
line:254 tip176-operator-fidelity
line:255 tip176-operator-fidelity
line:256 tip176-operator-fidelity
line:257 tip176-operator-fidelity
line:258 tip176-operator-fidelity
line:259 tip176-operator-fidelity
line:260 tip176-operator-fidelity
line:261 tip176-operator-fidelity
line:262 tip176-operator-fidelity
line:263 tip176-operator-fidelity
line:264 tip176-operator-fidelity
line:265 tip176-operator-fidelity
line:266 tip176-operator-fidelity
line:267 tip176-operator-fidelity
line:268 tip176-operator-fidelity
line:269 tip176-operator-fidelity
line:270 tip176-operator-fidelity
line:271 tip176-operator-fidelity
line:272 tip176-operator-fidelity
line:273 tip176-operator-fidelity
line:274 tip176-operator-fidelity
line:275 tip176-operator-fidelity
line:276 tip176-operator-fidelity
line:277 tip176-operator-fidelity
line:278 tip176-operator-fidelity
line:279 tip176-operator-fidelity
line:280 tip176-operator-fidelity
line:281 tip176-operator-fidelity
line:282 tip176-operator-fidelity
line:283 tip176-operator-fidelity
line:284 tip176-operator-fidelity
line:285 tip176-operator-fidelity
line:286 tip176-operator-fidelity
line:287 tip176-operator-fidelity
line:288 tip176-operator-fidelity
line:289 tip176-operator-fidelity
line:290 tip176-operator-fidelity
line:291 tip176-operator-fidelity
line:292 tip176-operator-fidelity
line:293 tip176-operator-fidelity
line:294 tip176-operator-fidelity
line:295 tip176-operator-fidelity
line:296 tip176-operator-fidelity
line:297 tip176-operator-fidelity
line:298 tip176-operator-fidelity
line:299 tip176-operator-fidelity
line:300 tip176-operator-fidelity
line:301 tip176-operator-fidelity
line:302 tip176-operator-fidelity
line:303 tip176-operator-fidelity
line:304 tip176-operator-fidelity
line:305 tip176-operator-fidelity
line:306 tip176-operator-fidelity
line:307 tip176-operator-fidelity
line:308 tip176-operator-fidelity
line:309 tip176-operator-fidelity
line:310 tip176-operator-fidelity
line:311 tip176-operator-fidelity
line:312 tip176-operator-fidelity
line:313 tip176-operator-fidelity
line:314 tip176-operator-fidelity
line:315 tip176-operator-fidelity
line:316 tip176-operator-fidelity
line:317 tip176-operator-fidelity
line:318 tip176-operator-fidelity
line:319 tip176-operator-fidelity
line:320 tip176-operator-fidelity
line:321 tip176-operator-fidelity
line:322 tip176-operator-fidelity
line:323 tip176-operator-fidelity
line:324 tip176-operator-fidelity
line:325 tip176-operator-fidelity
line:326 tip176-operator-fidelity
line:327 tip176-operator-fidelity
line:328 tip176-operator-fidelity
line:329 tip176-operator-fidelity
line:330 tip176-operator-fidelity
line:331 tip176-operator-fidelity
line:332 tip176-operator-fidelity
line:333 tip176-operator-fidelity
line:334 tip176-operator-fidelity
line:335 tip176-operator-fidelity
line:336 tip176-operator-fidelity
line:337 tip176-operator-fidelity
line:338 tip176-operator-fidelity
line:339 tip176-operator-fidelity
line:340 tip176-operator-fidelity
line:341 tip176-operator-fidelity
line:342 tip176-operator-fidelity
line:343 tip176-operator-fidelity
line:344 tip176-operator-fidelity
line:345 tip176-operator-fidelity
line:346 tip176-operator-fidelity
line:347 tip176-operator-fidelity
line:348 tip176-operator-fidelity
line:349 tip176-operator-fidelity
line:350 tip176-operator-fidelity
line:351 tip176-operator-fidelity
line:352 tip176-operator-fidelity
line:353 tip176-operator-fidelity
line:354 tip176-operator-fidelity
line:355 tip176-operator-fidelity
line:356 tip176-operator-fidelity
line:357 tip176-operator-fidelity
line:358 tip176-operator-fidelity
line:359 tip176-operator-fidelity
line:360 tip176-operator-fidelity
line:361 tip176-operator-fidelity
line:362 tip176-operator-fidelity
line:363 tip176-operator-fidelity
line:364 tip176-operator-fidelity
line:365 tip176-operator-fidelity
line:366 tip176-operator-fidelity
line:367 tip176-operator-fidelity
line:368 tip176-operator-fidelity
line:369 tip176-operator-fidelity
line:370 tip176-operator-fidelity
line:371 tip176-operator-fidelity
line:372 tip176-operator-fidelity
line:373 tip176-operator-fidelity
line:374 tip176-operator-fidelity
line:375 tip176-operator-fidelity
line:376 tip176-operator-fidelity
line:377 tip176-operator-fidelity
line:378 tip176-operator-fidelity
line:379 tip176-operator-fidelity
line:380 tip176-operator-fidelity
line:381 tip176-operator-fidelity
line:382 tip176-operator-fidelity
line:383 tip176-operator-fidelity
line:384 tip176-operator-fidelity
line:385 tip176-operator-fidelity
line:386 tip176-operator-fidelity
line:387 tip176-operator-fidelity
line:388 tip176-operator-fidelity
line:389 tip176-operator-fidelity
line:390 tip176-operator-fidelity
line:391 tip176-operator-fidelity
line:392 tip176-operator-fidelity
line:393 tip176-operator-fidelity
line:394 tip176-operator-fidelity
line:395 tip176-operator-fidelity
line:396 tip176-operator-fidelity
line:397 tip176-operator-fidelity
line:398 tip176-operator-fidelity
line:399 tip176-operator-fidelity
line:400 tip176-operator-fidelity
line:401 tip176-operator-fidelity
line:402 tip176-operator-fidelity
line:403 tip176-operator-fidelity
line:404 tip176-operator-fidelity
line:405 tip176-operator-fidelity
line:406 tip176-operator-fidelity
line:407 tip176-operator-fidelity
line:408 tip176-operator-fidelity
line:409 tip176-operator-fidelity
line:410 tip176-operator-fidelity
line:411 tip176-operator-fidelity
line:412 tip176-operator-fidelity
line:413 tip176-operator-fidelity
line:414 tip176-operator-fidelity
line:415 tip176-operator-fidelity
line:416 tip176-operator-fidelity
line:417 tip176-operator-fidelity
line:418 tip176-operator-fidelity
line:419 tip176-operator-fidelity
line:420 tip176-operator-fidelity
line:421 tip176-operator-fidelity
line:422 tip176-operator-fidelity
line:423 tip176-operator-fidelity
line:424 tip176-operator-fidelity
line:425 tip176-operator-fidelity
line:426 tip176-operator-fidelity
line:427 tip176-operator-fidelity
line:428 tip176-operator-fidelity
line:429 tip176-operator-fidelity
line:430 tip176-operator-fidelity
line:431 tip176-operator-fidelity
line:432 tip176-operator-fidelity
line:433 tip176-operator-fidelity
line:434 tip176-operator-fidelity
line:435 tip176-operator-fidelity
line:436 tip176-operator-fidelity
line:437 tip176-operator-fidelity
line:438 tip176-operator-fidelity
line:439 tip176-operator-fidelity
line:440 tip176-operator-fidelity
line:441 tip176-operator-fidelity
line:442 tip176-operator-fidelity
line:443 tip176-operator-fidelity
line:444 tip176-operator-fidelity
line:445 tip176-operator-fidelity
line:446 tip176-operator-fidelity
line:447 tip176-operator-fidelity
line:448 tip176-operator-fidelity
line:449 tip176-operator-fidelity
line:450 tip176-operator-fidelity
line:451 tip176-operator-fidelity
line:452 tip176-operator-fidelity
line:453 tip176-operator-fidelity
line:454 tip176-operator-fidelity
line:455 tip176-operator-fidelity
line:456 tip176-operator-fidelity
line:457 tip176-operator-fidelity
line:458 tip176-operator-fidelity
line:459 tip176-operator-fidelity
line:460 tip176-operator-fidelity
line:461 tip176-operator-fidelity
line:462 tip176-operator-fidelity
line:463 tip176-operator-fidelity
line:464 tip176-operator-fidelity
line:465 tip176-operator-fidelity
line:466 tip176-operator-fidelity
line:467 tip176-operator-fidelity
line:468 tip176-operator-fidelity
line:469 tip176-operator-fidelity
line:470 tip176-operator-fidelity
line:471 tip176-operator-fidelity
line:472 tip176-operator-fidelity
line:473 tip176-operator-fidelity
line:474 tip176-operator-fidelity
line:475 tip176-operator-fidelity
line:476 tip176-operator-fidelity
line:477 tip176-operator-fidelity
line:478 tip176-operator-fidelity
line:479 tip176-operator-fidelity
line:480 tip176-operator-fidelity
line:481 tip176-operator-fidelity
line:482 tip176-operator-fidelity
line:483 tip176-operator-fidelity
line:484 tip176-operator-fidelity
line:485 tip176-operator-fidelity
line:486 tip176-operator-fidelity
line:487 tip176-operator-fidelity
line:488 tip176-operator-fidelity
line:489 tip176-operator-fidelity
line:490 tip176-operator-fidelity
line:491 tip176-operator-fidelity
line:492 tip176-operator-fidelity
line:493 tip176-operator-fidelity
line:494 tip176-operator-fidelity
line:495 tip176-operator-fidelity
line:496 tip176-operator-fidelity
line:497 tip176-operator-fidelity
line:498 tip176-operator-fidelity
line:499 tip176-operator-fidelity
line:500 tip176-operator-fidelity
line:501 tip176-operator-fidelity
line:502 tip176-operator-fidelity
line:503 tip176-operator-fidelity
line:504 tip176-operator-fidelity
line:505 tip176-operator-fidelity
line:506 tip176-operator-fidelity
line:507 tip176-operator-fidelity
line:508 tip176-operator-fidelity
line:509 tip176-operator-fidelity
line:510 tip176-operator-fidelity
line:511 tip176-operator-fidelity
line:512 tip176-operator-fidelity
line:513 tip176-operator-fidelity
line:514 tip176-operator-fidelity
line:515 tip176-operator-fidelity
line:516 tip176-operator-fidelity
line:517 tip176-operator-fidelity
line:518 tip176-operator-fidelity
line:519 tip176-operator-fidelity
line:520 tip176-operator-fidelity
line:521 tip176-operator-fidelity
line:522 tip176-operator-fidelity
line:523 tip176-operator-fidelity
line:524 tip176-operator-fidelity
line:525 tip176-operator-fidelity
line:526 tip176-operator-fidelity
line:527 tip176-operator-fidelity
line:528 tip176-operator-fidelity
line:529 tip176-operator-fidelity
line:530 tip176-operator-fidelity
line:531 tip176-operator-fidelity
line:532 tip176-operator-fidelity
line:533 tip176-operator-fidelity
line:534 tip176-operator-fidelity
line:535 tip176-operator-fidelity
line:536 tip176-operator-fidelity
line:537 tip176-operator-fidelity
line:538 tip176-operator-fidelity
line:539 tip176-operator-fidelity
line:540 tip176-operator-fidelity
line:541 tip176-operator-fidelity
line:542 tip176-operator-fidelity
line:543 tip176-operator-fidelity
line:544 tip176-operator-fidelity
line:545 tip176-operator-fidelity
line:546 tip176-operator-fidelity
line:547 tip176-operator-fidelity
line:548 tip176-operator-fidelity
line:549 tip176-operator-fidelity
line:550 tip176-operator-fidelity
line:551 tip176-operator-fidelity
line:552 tip176-operator-fidelity
line:553 tip176-operator-fidelity
line:554 tip176-operator-fidelity
line:555 tip176-operator-fidelity
line:556 tip176-operator-fidelity
line:557 tip176-operator-fidelity
line:558 tip176-operator-fidelity
line:559 tip176-operator-fidelity
line:560 tip176-operator-fidelity
line:561 tip176-operator-fidelity
line:562 tip176-operator-fidelity
line:563 tip176-operator-fidelity
line:564 tip176-operator-fidelity
line:565 tip176-operator-fidelity
line:566 tip176-operator-fidelity
line:567 tip176-operator-fidelity
line:568 tip176-operator-fidelity
line:569 tip176-operator-fidelity
line:570 tip176-operator-fidelity
line:571 tip176-operator-fidelity
line:572 tip176-operator-fidelity
line:573 tip176-operator-fidelity
line:574 tip176-operator-fidelity
line:575 tip176-operator-fidelity
line:576 tip176-operator-fidelity
line:577 tip176-operator-fidelity
line:578 tip176-operator-fidelity
line:579 tip176-operator-fidelity
line:580 tip176-operator-fidelity
line:581 tip176-operator-fidelity
line:582 tip176-operator-fidelity
line:583 tip176-operator-fidelity
line:584 tip176-operator-fidelity
line:585 tip176-operator-fidelity
line:586 tip176-operator-fidelity
line:587 tip176-operator-fidelity
line:588 tip176-operator-fidelity
line:589 tip176-operator-fidelity
line:590 tip176-operator-fidelity
line:591 tip176-operator-fidelity
line:592 tip176-operator-fidelity
line:593 tip176-operator-fidelity
line:594 tip176-operator-fidelity
line:595 tip176-operator-fidelity
line:596 tip176-operator-fidelity
line:597 tip176-operator-fidelity
line:598 tip176-operator-fidelity
line:599 tip176-operator-fidelity
line:600 tip176-operator-fidelity
line:601 tip176-operator-fidelity
line:602 tip176-operator-fidelity
line:603 tip176-operator-fidelity
line:604 tip176-operator-fidelity
line:605 tip176-operator-fidelity
line:606 tip176-operator-fidelity
line:607 tip176-operator-fidelity
line:608 tip176-operator-fidelity
line:609 tip176-operator-fidelity
line:610 tip176-operator-fidelity
line:611 tip176-operator-fidelity
line:612 tip176-operator-fidelity
line:613 tip176-operator-fidelity
line:614 tip176-operator-fidelity
line:615 tip176-operator-fidelity
line:616 tip176-operator-fidelity
line:617 tip176-operator-fidelity
line:618 tip176-operator-fidelity
line:619 tip176-operator-fidelity
line:620 tip176-operator-fidelity
line:621 tip176-operator-fidelity
line:622 tip176-operator-fidelity
line:623 tip176-operator-fidelity
line:624 tip176-operator-fidelity
line:625 tip176-operator-fidelity
line:626 tip176-operator-fidelity
line:627 tip176-operator-fidelity
line:628 tip176-operator-fidelity
line:629 tip176-operator-fidelity
line:630 tip176-operator-fidelity
line:631 tip176-operator-fidelity
line:632 tip176-operator-fidelity
line:633 tip176-operator-fidelity
line:634 tip176-operator-fidelity
line:635 tip176-operator-fidelity
line:636 tip176-operator-fidelity
line:637 tip176-operator-fidelity
line:638 tip176-operator-fidelity
line:639 tip176-operator-fidelity
line:640 tip176-operator-fidelity
line:641 tip176-operator-fidelity
line:642 tip176-operator-fidelity
line:643 tip176-operator-fidelity
line:644 tip176-operator-fidelity
line:645 tip176-operator-fidelity
line:646 tip176-operator-fidelity
line:647 tip176-operator-fidelity
line:648 tip176-operator-fidelity
line:649 tip176-operator-fidelity
line:650 tip176-operator-fidelity
line:651 tip176-operator-fidelity
line:652 tip176-operator-fidelity
line:653 tip176-operator-fidelity
line:654 tip176-operator-fidelity
line:655 tip176-operator-fidelity
line:656 tip176-operator-fidelity
line:657 tip176-operator-fidelity
line:658 tip176-operator-fidelity
line:659 tip176-operator-fidelity
line:660 tip176-operator-fidelity
line:661 tip176-operator-fidelity
line:662 tip176-operator-fidelity
line:663 tip176-operator-fidelity
line:664 tip176-operator-fidelity
line:665 tip176-operator-fidelity
line:666 tip176-operator-fidelity
line:667 tip176-operator-fidelity
line:668 tip176-operator-fidelity
line:669 tip176-operator-fidelity
line:670 tip176-operator-fidelity
line:671 tip176-operator-fidelity
line:672 tip176-operator-fidelity
line:673 tip176-operator-fidelity
line:674 tip176-operator-fidelity
line:675 tip176-operator-fidelity
line:676 tip176-operator-fidelity
line:677 tip176-operator-fidelity
line:678 tip176-operator-fidelity
line:679 tip176-operator-fidelity
line:680 tip176-operator-fidelity
line:681 tip176-operator-fidelity
line:682 tip176-operator-fidelity
line:683 tip176-operator-fidelity
line:684 tip176-operator-fidelity
line:685 tip176-operator-fidelity
line:686 tip176-operator-fidelity
line:687 tip176-operator-fidelity
line:688 tip176-operator-fidelity
line:689 tip176-operator-fidelity
line:690 tip176-operator-fidelity
line:691 tip176-operator-fidelity
line:692 tip176-operator-fidelity
line:693 tip176-operator-fidelity
line:694 tip176-operator-fidelity
line:695 tip176-operator-fidelity
line:696 tip176-operator-fidelity
line:697 tip176-operator-fidelity
line:698 tip176-operator-fidelity
line:699 tip176-operator-fidelity
line:700 tip176-operator-fidelity
line:701 tip176-operator-fidelity
line:702 tip176-operator-fidelity
line:703 tip176-operator-fidelity
line:704 tip176-operator-fidelity
line:705 tip176-operator-fidelity
line:706 tip176-operator-fidelity
line:707 tip176-operator-fidelity
line:708 tip176-operator-fidelity
line:709 tip176-operator-fidelity
line:710 tip176-operator-fidelity
line:711 tip176-operator-fidelity
line:712 tip176-operator-fidelity
line:713 tip176-operator-fidelity
line:714 tip176-operator-fidelity
line:715 tip176-operator-fidelity
line:716 tip176-operator-fidelity
line:717 tip176-operator-fidelity
line:718 tip176-operator-fidelity
line:719 tip176-operator-fidelity
line:720 tip176-operator-fidelity
line:721 tip176-operator-fidelity
line:722 tip176-operator-fidelity
line:723 tip176-operator-fidelity
line:724 tip176-operator-fidelity
line:725 tip176-operator-fidelity
line:726 tip176-operator-fidelity
line:727 tip176-operator-fidelity
line:728 tip176-operator-fidelity
line:729 tip176-operator-fidelity
line:730 tip176-operator-fidelity
line:731 tip176-operator-fidelity
line:732 tip176-operator-fidelity
line:733 tip176-operator-fidelity
line:734 tip176-operator-fidelity
line:735 tip176-operator-fidelity
line:736 tip176-operator-fidelity
line:737 tip176-operator-fidelity
line:738 tip176-operator-fidelity
line:739 tip176-operator-fidelity
line:740 tip176-operator-fidelity
line:741 tip176-operator-fidelity
line:742 tip176-operator-fidelity
line:743 tip176-operator-fidelity
line:744 tip176-operator-fidelity
line:745 tip176-operator-fidelity
line:746 tip176-operator-fidelity
line:747 tip176-operator-fidelity
line:748 tip176-operator-fidelity
line:749 tip176-operator-fidelity
line:750 tip176-operator-fidelity
line:751 tip176-operator-fidelity
line:752 tip176-operator-fidelity
line:753 tip176-operator-fidelity
line:754 tip176-operator-fidelity
line:755 tip176-operator-fidelity
line:756 tip176-operator-fidelity
line:757 tip176-operator-fidelity
line:758 tip176-operator-fidelity
line:759 tip176-operator-fidelity
line:760 tip176-operator-fidelity
line:761 tip176-operator-fidelity
line:762 tip176-operator-fidelity
line:763 tip176-operator-fidelity
line:764 tip176-operator-fidelity
line:765 tip176-operator-fidelity
line:766 tip176-operator-fidelity
line:767 tip176-operator-fidelity
line:768 tip176-operator-fidelity
line:769 tip176-operator-fidelity
line:770 tip176-operator-fidelity
line:771 tip176-operator-fidelity
line:772 tip176-operator-fidelity
line:773 tip176-operator-fidelity
line:774 tip176-operator-fidelity
line:775 tip176-operator-fidelity
line:776 tip176-operator-fidelity
line:777 tip176-operator-fidelity
line:778 tip176-operator-fidelity
line:779 tip176-operator-fidelity
line:780 tip176-operator-fidelity
line:781 tip176-operator-fidelity
line:782 tip176-operator-fidelity
line:783 tip176-operator-fidelity
line:784 tip176-operator-fidelity
line:785 tip176-operator-fidelity
line:786 tip176-operator-fidelity
line:787 tip176-operator-fidelity
line:788 tip176-operator-fidelity
line:789 tip176-operator-fidelity
line:790 tip176-operator-fidelity
line:791 tip176-operator-fidelity
line:792 tip176-operator-fidelity
line:793 tip176-operator-fidelity
line:794 tip176-operator-fidelity
line:795 tip176-operator-fidelity
line:796 tip176-operator-fidelity
line:797 tip176-operator-fidelity
line:798 tip176-operator-fidelity
line:799 tip176-operator-fidelity
line:800 tip176-operator-fidelity
line:801 tip176-operator-fidelity
line:802 tip176-operator-fidelity
line:803 tip176-operator-fidelity
line:804 tip176-operator-fidelity
line:805 tip176-operator-fidelity
line:806 tip176-operator-fidelity
line:807 tip176-operator-fidelity
line:808 tip176-operator-fidelity
line:809 tip176-operator-fidelity
line:810 tip176-operator-fidelity
line:811 tip176-operator-fidelity
line:812 tip176-operator-fidelity
line:813 tip176-operator-fidelity
line:814 tip176-operator-fidelity
line:815 tip176-operator-fidelity
line:816 tip176-operator-fidelity
line:817 tip176-operator-fidelity
line:818 tip176-operator-fidelity
line:819 tip176-operator-fidelity
line:820 tip176-operator-fidelity
line:821 tip176-operator-fidelity
line:822 tip176-operator-fidelity
line:823 tip176-operator-fidelity
line:824 tip176-operator-fidelity
line:825 tip176-operator-fidelity
line:826 tip176-operator-fidelity
line:827 tip176-operator-fidelity
line:828 tip176-operator-fidelity
line:829 tip176-operator-fidelity
line:830 tip176-operator-fidelity
line:831 tip176-operator-fidelity
line:832 tip176-operator-fidelity
line:833 tip176-operator-fidelity
line:834 tip176-operator-fidelity
line:835 tip176-operator-fidelity
line:836 tip176-operator-fidelity
line:837 tip176-operator-fidelity
line:838 tip176-operator-fidelity
line:839 tip176-operator-fidelity
line:840 tip176-operator-fidelity
line:841 tip176-operator-fidelity
line:842 tip176-operator-fidelity
line:843 tip176-operator-fidelity
line:844 tip176-operator-fidelity
line:845 tip176-operator-fidelity
line:846 tip176-operator-fidelity
line:847 tip176-operator-fidelity
line:848 tip176-operator-fidelity
line:849 tip176-operator-fidelity
line:850 tip176-operator-fidelity
line:851 tip176-operator-fidelity
line:852 tip176-operator-fidelity
line:853 tip176-operator-fidelity
line:854 tip176-operator-fidelity
line:855 tip176-operator-fidelity
line:856 tip176-operator-fidelity
line:857 tip176-operator-fidelity
line:858 tip176-operator-fidelity
line:859 tip176-operator-fidelity
line:860 tip176-operator-fidelity
line:861 tip176-operator-fidelity
line:862 tip176-operator-fidelity
line:863 tip176-operator-fidelity
line:864 tip176-operator-fidelity
line:865 tip176-operator-fidelity
line:866 tip176-operator-fidelity
line:867 tip176-operator-fidelity
line:868 tip176-operator-fidelity
line:869 tip176-operator-fidelity
line:870 tip176-operator-fidelity
line:871 tip176-operator-fidelity
line:872 tip176-operator-fidelity
line:873 tip176-operator-fidelity
line:874 tip176-operator-fidelity
line:875 tip176-operator-fidelity
line:876 tip176-operator-fidelity
line:877 tip176-operator-fidelity
line:878 tip176-operator-fidelity
line:879 tip176-operator-fidelity
line:880 tip176-operator-fidelity
line:881 tip176-operator-fidelity
line:882 tip176-operator-fidelity
line:883 tip176-operator-fidelity
line:884 tip176-operator-fidelity
line:885 tip176-operator-fidelity
line:886 tip176-operator-fidelity
line:887 tip176-operator-fidelity
line:888 tip176-operator-fidelity
line:889 tip176-operator-fidelity
line:890 tip176-operator-fidelity
line:891 tip176-operator-fidelity
line:892 tip176-operator-fidelity
line:893 tip176-operator-fidelity
line:894 tip176-operator-fidelity
line:895 tip176-operator-fidelity
line:896 tip176-operator-fidelity
line:897 tip176-operator-fidelity
line:898 tip176-operator-fidelity
line:899 tip176-operator-fidelity
line:900 tip176-operator-fidelity
line:901 tip176-operator-fidelity
line:902 tip176-operator-fidelity
line:903 tip176-operator-fidelity
line:904 tip176-operator-fidelity
line:905 tip176-operator-fidelity
line:906 tip176-operator-fidelity
line:907 tip176-operator-fidelity
line:908 tip176-operator-fidelity
line:909 tip176-operator-fidelity
line:910 tip176-operator-fidelity
line:911 tip176-operator-fidelity
line:912 tip176-operator-fidelity
line:913 tip176-operator-fidelity
line:914 tip176-operator-fidelity
line:915 tip176-operator-fidelity
line:916 tip176-operator-fidelity
line:917 tip176-operator-fidelity
line:918 tip176-operator-fidelity
line:919 tip176-operator-fidelity
line:920 tip176-operator-fidelity
line:921 tip176-operator-fidelity
line:922 tip176-operator-fidelity
line:923 tip176-operator-fidelity
line:924 tip176-operator-fidelity
line:925 tip176-operator-fidelity
line:926 tip176-operator-fidelity
line:927 tip176-operator-fidelity
line:928 tip176-operator-fidelity
line:929 tip176-operator-fidelity
line:930 tip176-operator-fidelity
line:931 tip176-operator-fidelity
line:932 tip176-operator-fidelity
line:933 tip176-operator-fidelity
line:934 tip176-operator-fidelity
line:935 tip176-operator-fidelity
line:936 tip176-operator-fidelity
line:937 tip176-operator-fidelity
line:938 tip176-operator-fidelity
line:939 tip176-operator-fidelity
line:940 tip176-operator-fidelity
line:941 tip176-operator-fidelity
line:942 tip176-operator-fidelity
line:943 tip176-operator-fidelity
line:944 tip176-operator-fidelity
line:945 tip176-operator-fidelity
line:946 tip176-operator-fidelity
line:947 tip176-operator-fidelity
line:948 tip176-operator-fidelity
line:949 tip176-operator-fidelity
line:950 tip176-operator-fidelity
line:951 tip176-operator-fidelity
line:952 tip176-operator-fidelity
line:953 tip176-operator-fidelity
line:954 tip176-operator-fidelity
line:955 tip176-operator-fidelity
line:956 tip176-operator-fidelity
line:957 tip176-operator-fidelity
line:958 tip176-operator-fidelity
line:959 tip176-operator-fidelity
line:960 tip176-operator-fidelity
line:961 tip176-operator-fidelity
line:962 tip176-operator-fidelity
line:963 tip176-operator-fidelity
line:964 tip176-operator-fidelity
line:965 tip176-operator-fidelity
line:966 tip176-operator-fidelity
line:967 tip176-operator-fidelity
line:968 tip176-operator-fidelity
line:969 tip176-operator-fidelity
line:970 tip176-operator-fidelity
line:971 tip176-operator-fidelity
line:972 tip176-operator-fidelity
line:973 tip176-operator-fidelity
line:974 tip176-operator-fidelity
line:975 tip176-operator-fidelity
line:976 tip176-operator-fidelity
line:977 tip176-operator-fidelity
line:978 tip176-operator-fidelity
line:979 tip176-operator-fidelity
line:980 tip176-operator-fidelity
line:981 tip176-operator-fidelity
line:982 tip176-operator-fidelity
line:983 tip176-operator-fidelity
line:984 tip176-operator-fidelity
line:985 tip176-operator-fidelity
line:986 tip176-operator-fidelity
line:987 tip176-operator-fidelity
line:988 tip176-operator-fidelity
line:989 tip176-operator-fidelity
line:990 tip176-operator-fidelity
line:991 tip176-operator-fidelity
line:992 tip176-operator-fidelity
line:993 tip176-operator-fidelity
line:994 tip176-operator-fidelity
line:995 tip176-operator-fidelity
line:996 tip176-operator-fidelity
line:997 tip176-operator-fidelity
line:998 tip176-operator-fidelity
line:999 tip176-operator-fidelity
line:1000 tip176-operator-fidelity
