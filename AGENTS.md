# Hermes Mac Land — Agent Notes

- Official repo for Hermes **deployment** onto live `.11` (`four-openclaw`). Ooterverse-Saturns-Quest is game-only.
- Cloud agents: boot from **web UI** on this repo with the saved environment **Hermes Mac Landing**. Attach only the runtime secrets required by the exact deployment task, such as `TS_AUTHKEY` and `HERMES_HOST_SSH_PRIVATE_KEY`.
- `.cursor/environment.json` runs `hermes-cloud-agent-start.sh` on boot (waiter + auto surgical land when secrets present).
- Mac land: `curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash`
- Success path: RAL-820 interrupt canary **Done** (zero-model `1097131`). Next: stage RAL-793 own contract on `.11` (`docs/RAL-793-CONTRACT-STAGING.md`) → `DISPATCH-NOW RAL-793` → CLAIMED + inventory; parallel RAL-800 tip-main land. No Slack rockets.
- Do **not** `hermes-now` / `DISPATCH-NOW` on RAL-793 until its execution contract is pinned live (accidental CLAIMED 2026-08-25 was reverted).
- Core Hermes Agent, CLI, gateway, provider, skill, memory, or agent-loop development belongs in `ilike4movies/hermes-agent-cos`, not this deployment repository.
- Default routine Cursor work to Composer 2.5 Fast. Use one accountable agent and never enable paid overage without Ralph's exact approval.
