---
title: 'Epic 5 retro item 31: reconcile the Epic 5 docs with the as-built'
type: 'chore'
created: '2026-10-16'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Epic 5 retro (`epic-5-retro-2026-10-16.md`, findings 3, 4, 5 and the 5.2 review notes; action 3 = sprint action item 31) found that the docs no longer match what Epic 5 built. The non-goal "No alerts in this epic" ignores the three Synthetic Monitoring alert rules Story 5.2 created (`grafana-cloud/opentofu/checks.tf`), and `monitoring.md:3` still says "alerting comes later". The 5.2 AC says the check "fails" when the certificate expires within 14 days, but only its alert fires (the check itself fails only on an invalid certificate). The 5.3 AC in the epics file lists neither the log-volume panels and the Caddy-only `stream` label nor the global masking `log` block and the deleted forwarded-IP headers. `synthetic-monitoring.md` does not say that nothing in the repo routes the alerts to a contact point, or how long a failure takes to fire an alert.

**Approach:** Fix the wording in place, with no behavior change: `epic-5-context.md` (non-goal, plus the probe-target lines Epic 7 made stale), the 5.2 and 5.3 ACs in `epics-fantasy-hockey-digitalocean.md`, the alert non-goal in `spec-fantasy-hockey-digitalocean` (`SPEC.md`, `epics.md`, `platform-decisions.md`), `docs/cloud/digital-ocean/monitoring.md` (intro and Checks) and a section in `docs/grafana-cloud/synthetic-monitoring.md` on alert routing and detection latency. The rule becomes: the dashboard has no alert rules; the only alerts are the three built-in rules of each Synthetic Monitoring check, which are not routed anywhere yet (that decision is action item 32). `stories.yaml` stays as the historical record of the story inputs.

</frozen-after-approval>

## Implementation Notes

- Finding 3 (non-goal vs 5.2 alerts): `epic-5-context.md`, `SPEC.md`, spec `epics.md` and `platform-decisions.md` now say the dashboard has no alert rules, the only alerts are the three built-in rules of the synthetic check, and they are not routed to a contact point (decision: item 32). `monitoring.md` intro links to the new routing section; its Checks gain a step that the three rules exist. The 5.1 and 5.3 ACs say "no alert rules".
- Finding 4 (5.2 AC wording): the AC in `epics-fantasy-hockey-digitalocean.md` and the line in `epic-7-context.md` say the check fails on an invalid certificate and its `TLSTargetCertificateCloseToExpiring` alert fires within 14 days.
- Finding 5 (5.3 AC): adds the Caddy-only `stream` label, the log-volume panels and donuts, the global `log` block masking and the deleted `X-Forwarded-For`/`X-Real-Ip`/`Forwarded` headers.
- 5.2 review notes: `synthetic-monitoring.md` § Alert Routing and Detection Time (no contact point or policy in the repo; a fire/clear table per alert; one location alone can fire `ProbeFailedExecutionsTooHigh`). The timings are estimates with their assumptions stated, not measured.
- Also stale since Epic 7, fixed in `epic-5-context.md`: probe target (domain, not `http://<reserved-ip>`), nginx → Caddy, the dependency on Epic 7, and the 5.2 open question marked settled. `stories.yaml` left as the historical record of story inputs.
- `task lint` passes (lychee resolves the new anchor).

## Review Triage Log

Blind Hunter, one pass (floor N = 4, 11 findings).

| #  | Finding                                                                             | Verdict     | Route  | Evidence                                                                                                                                 |
|----|-------------------------------------------------------------------------------------|-------------|--------|------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | `epic-7-context.md:40` keeps the wrong 5.2 "fails … within 14 days" wording         | low         | patch  | Same sentence as the 5.2 AC; reworded the same way                                                                                       |
| 2  | `epic-5-context.md` still says "nginx plus the app"                                 | low         | patch  | Caddy replaced nginx in 7.2; now "Caddy plus the app since Epic 7"                                                                       |
| 3  | The 5.2 open question in `epic-5-context.md` is still listed as open                | low         | patch  | Settled by the OpenTofu checks; marked settled                                                                                           |
| 4  | The item-32 parenthetical misattributes the reconciliation                          | low         | patch  | Reworded: item 32 is the routing decision, item 31 the reconciliation                                                                    |
| 5  | The 5.1 and 5.3 ACs still say "no alerts"                                           | medium      | patch  | Lines 363 and 394; now "no alert rules"                                                                                                  |
| 6  | `monitoring.md` Checks unchanged although the Approach names it                     | medium      | patch  | Added a check that the three rules exist with 14 days and 300 ms                                                                         |
| 7  | Detection time assumes `>` and ignores the evaluation interval and pending period   | maybe-false | patch  | Not verifiable without the generated rule in Grafana Cloud. The section now states both assumptions and says to check the generated rule |
| 8  | Section covers only `ProbeFailedExecutionsTooHigh`, not recovery or the other rules | low         | patch  | Replaced the paragraph with a fire/clear table for all three rules                                                                       |
| 9  | Single-location case gives no number                                                | low         | patch  | Now about 20 to 30 minutes, same estimate basis                                                                                          |
| 10 | Spec incomplete (status, empty notes, no tasks or ACs)                              | false       | reject | The oneshot route writes only Intent and Implementation Notes; status and notes are set at finalize, as in the item-24 spec              |
| 11 | `SPEC.md` omits that the alerts are not routed                                      | low         | patch  | One clause added to match `epics.md` and `platform-decisions.md`                                                                         |
