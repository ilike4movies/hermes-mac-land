### Tip #189 (Path C re-probe exhausted; ICS tip-pin catch-up)

- Re-tried Path C @ ~11:40–11:45Z: Zapier `put_workflow_file_via_git_data` (regenerated connected-account-only) still **Bad credentials** on GET ref; `put_file_from_repo` Bad credentials; Zapier `create_file` File Lookup Error; Github MCP Contents/trees **404** on `.github/workflows/`; git push auth fail.
- Actions `total_count=0` until workflow lands under `.github/workflows/downstream-stall.yml`.
- Stall chain tip-synced on cloud-apply: `hermes-join-part-b.sh` 29423 `bash -n` OK; defaults `HERMES_RUN_ID=20260826T232521106484Z-2954673` zombie=1 passes=3.
- Operator wake: Quo SMS tip#189 delivered; Dropbox `/WAKE-1d0d8050-tip183.txt` tip#189 body; GH#1 comment; `TIP_PIN=189`; ICS SUMMARY tip #189 soft-hold push (DTEND preserved).
- Prefer Mac ONE-SHOT tip **#183** / Tailscale approve `1d0d8050`. Path C secondary until Zapier GH reconnect:
  https://mcp.zapier.com/api/v1/connect-auth/GitHubCLIAPI?accountId=12547336&connectionId=55525043
  or Web UI Raw paste [`ci/downstream-stall.yml`](ci/downstream-stall.yml) → `.github/workflows/downstream-stall.yml` + Action secrets.
- Obj5 (RAL-793) still OPEN: needs machine `## Downstream DONE` + live `evidence/RAL-793-inventory.md`.
