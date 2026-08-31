# OPERATOR UNBLOCK — Hermes Mac Land

Soft-hold + TIP_PIN=182 already on main. Finish tip #182 docs/launchers.

### Tip #182 (ICS soft-hold prefers hermes-mac-land over cloud-apply)

- [`hermes-ics-soft-hold.sh`](shared-scripts/hermes-ics-soft-hold.sh) picks the working dir with the highest `TIP_PIN`, preferring `/tmp/hermes-mac-land` on ties.
- Closes: tip-stale soft-hold wrote ICS/CURRENT into `/tmp/hermes-cloud-apply` (first match) while agents push from hermes-mac-land — rewrites never reached main until manual copy.
- Path C Zapier put_workflow / put_file_from_repo still **Bad credentials**.
