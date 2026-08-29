### Tip #156 (Downstream status post: timeout gh + curl fallback)

- [`hermes-dispatcher-part-a.sh`](shared-scripts/hermes-dispatcher-part-a.sh) `_post_github_status`: was gh-only, silent fail — Mac ONE-SHOT/STALL could finish inventory wait and still leave issue #1 without `## Downstream DONE @ …` (obj5 gates + tip#154/#155 NAG never see success).
- Now: `timeout` around `gh issue comment` (default 8s); curl+token fallback (`HERMES_STATUS_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN` / `gh auth token`); OK/WARN log lines.
