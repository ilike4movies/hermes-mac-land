# Hermes Mac Land — Agent Notes

- Official repo for Hermes **deployment** onto live `.11` (`four-openclaw`). Ooterverse-Saturns-Quest is game-only.
- Cloud agents: boot from **web UI** on this repo with saved environment **LEGACY Hermes .11 — do not use for Ooterverse** + Runtime Secrets `TS_AUTHKEY`, `HERMES_HOST_SSH_PRIVATE_KEY`.
- `.cursor/environment.json` runs `hermes-cloud-agent-start.sh` on boot (waiter + auto surgical land when secrets present).
- Mac land: `curl -fsSL https://raw.githubusercontent.com/ilike4movies/hermes-mac-land/main/hermes-mac-land.sh | bash`
- Success: `OK INTERRUPT_LABEL hermes-now` → RAL-800 Host surgical-apply OK → RAL-793 Hermes CLAIMED. No Slack rockets.
