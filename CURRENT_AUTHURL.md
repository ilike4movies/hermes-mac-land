# Live cloud Tailscale AuthURL

**Last refreshed:** 2026-08-28T13:47:26Z (tip #90 refreshes ~45m while NeedsLogin)

**Approve:** https://login.tailscale.com/a/1ae3f2f7017bf2

Do **not** use older AuthURLs (`19adccba`, `f073a6`, `2437b4`, …). Prefer Mac ONE-SHOT if Runtime Secrets stay unset.

After approve, cloud still needs `HERMES_HOST_SSH_PRIVATE_KEY` (+ preferably `LINEAR_API_KEY` / `TS_AUTHKEY`) unless Mac ONE-SHOT completes Downstream DONE.

Hostname to approve: `cursor-cloud-hermes`

Admin: https://login.tailscale.com/admin/machines

Tip also has #97/#98: inventory wait 900s + AuthURL tip beacon harden.
