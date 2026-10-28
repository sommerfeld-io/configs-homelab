---
title: 'Reconcile runbook M13 and the Epic 8 AC with the as-built'
type: 'chore'
created: '2026-10-28'
status: 'done'
route: 'dispatch'
baseline_commit: '32dfb1dd18109e19f3626d1bcc9f1f222caf7266'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The DNS delegation runbook presents M13 ("wait 2 × 7200 s after M10") as a hard gate before M14 deletes the KAS A record, and the Story 8.2 AC names that wait as its precondition. On 2026-10-22 the operator skipped it (M10 18:06:05 UTC, M14 18:10:02 UTC) without harm, because the observable condition the wait protects was already true. The runbook and AC still state only the time, not the condition (Epic 8 retro A1, P2, item 38).

**Approach:** Rewrite M13 (and every place that mirrors it) so the gate names the observable condition it protects, reword the Story 8.2 AC precondition to match, and record the skipped wait in the `domain.md` History.

## Boundaries & Constraints

**Always:** State the observable condition: `ns5` and `ns6.kasserver.com` both return a referral (`flags: qr` without `aa`, `ANSWER: 0`, the three DigitalOcean NS in the authority section) and `+trace` ends at `nsN.digitalocean.com`. Keep step IDs M7–M16 and their anchors stable (`domain.md` links to `#m10-…` and `#m14-…`). Keep the overview table padded per the markdown table rule.

**Never:** Edit the done spec `spec-8-2-…md` (its Operator results already record the skip as history). Change R1–R4, M7–M12 or M15–M16 beyond what mirrors M13. Commit — the user commits.

**Decision (2026-10-28, option A):** the condition replaces the wait. M13 becomes "Confirm the delegation is authoritative": M14 may run as soon as the condition holds, re-checked once right before M14; the 2 × TTL wait is dropped. Rationale for the docs: once the KAS refers, the A record is occluded and never served, and any resolver holding a cached copy holds the same IP, so the wait protects nothing extra. The Story 8.2 AC precondition becomes this condition plus HTTPS verified from outside.

</frozen-after-approval>

## Code Map

- `docs/cloud/digital-ocean/dns-delegation.md:115` -- overview table row M13 (Where column "calendar, then as M11 and M12").
- `docs/cloud/digital-ocean/dns-delegation.md:181-187` -- `### M13: Wait Two TTLs`: heading, When/Where/Action/Why. Heading change changes the anchor; nothing links to `#m13-…` (checked by grep).
- `docs/cloud/digital-ocean/dns-delegation.md:189-196` -- M14 "When: only after M13's wait has passed" and "Outage risk: … M11 to M13 excluded".
- `docs/cloud/digital-ocean/dns-delegation.md:432-438` -- PlantUML diagram C, `group Wait 2 x TTL`.
- `docs/cloud/digital-ocean/dns-delegation.md` Verification Commands `### Authoritative KAS` / `### Trace` -- reuse as the link targets for the condition; do not duplicate commands.
- `docs/cloud/digital-ocean/domain.md:72-80` -- History table; add the skipped-wait note between the M10 and M14 rows (or in the M14 row).
- `_bmad-output/planning-artifacts/epics-fantasy-hockey-digitalocean.md:477` -- Story 8.2 AC "Given the delegation verified for at least twice the KAS TTL …".
- `_bmad-output/implementation-artifacts/sprint-status.yaml:377-383` -- item 38, `status: open` → `done`.
- `_bmad-output/implementation-artifacts/spec-8-2-…md:192` -- reference only: wording and evidence of the skip.

## Tasks & Acceptance

**Execution:**

- [x] `docs/cloud/digital-ocean/dns-delegation.md` -- rewrite M13 per the decision, update its table row, M14 When/Outage risk and the diagram C group -- runbook gate states its observable condition.
- [x] `docs/cloud/digital-ocean/domain.md` -- add a History entry dated 2026-10-22 that the M13 wait was skipped (A record deleted 4 min after M10) and why it was safe -- as-built record.
- [x] `_bmad-output/planning-artifacts/epics-fantasy-hockey-digitalocean.md` -- reword the Story 8.2 AC precondition to match the decision -- AC matches the runbook and the as-built.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- set item 38 to `done` -- close the action item.

**Acceptance Criteria:**

- Given the runbook, when an operator reads M13 and M14, then the gate for M14 names the referral on both KAS nameservers and the `+trace` ending at DigitalOcean, and no text still requires the 2 × TTL wait.
- Given `domain.md` History, when read, then the 2026-10-22 skip of the M13 wait and the reason it was harmless are recorded.
- Given the Story 8.2 AC, when compared with `spec-8-2` Operator results, then the as-built meets it.
- Given the changed files, when `task lint` runs, then markdown and link checks pass.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| Finding                                                      | Verdict     | Route  | Evidence                                                                                                                                          |
|--------------------------------------------------------------|-------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| B1 M13 failure line vs Rollback R1 (blind)                   | medium      | patch  | M13 says "continue with M11" and "Rollback: red → R1"; table row lists R1. Grouped with B4/E3.                                                    |
| B4/E3 M13 failure loop has no exit, no ticket (blind, edge)  | medium      | patch  | "continue with M11" has no timebox; M11 holds the ticket and the 4 h → R1 rule. Same root cause as B1.                                            |
| B2/E1 DigitalOcean A value never compared (blind, edge)      | low         | patch  | Why relies on "same IP DigitalOcean answers"; Condition checks only referral and trace end. Fix: one clause in the Condition.                     |
| B3/E4 M14 Verify checks only ns5 (blind, edge)               | low         | patch  | M14 Verify reads "`ns5.kasserver.com` still refers" while M13 requires both. Direct correction.                                                   |
| B5 M13 first run duplicates M11; prose vs diagram (blind)    | low         | patch  | When: "after M12, and once more right before M14"; diagram shows one check. Grouped with E5.                                                      |
| E5 "right before" has no bound (edge)                        | low         | patch  | M13, M14 and the AC say "right before" with no limit; a stale result could be reused. Wording fix.                                                |
| B7 +trace arrow suggests a direct DigitalOcean query (blind) | low         | patch  | Diagram C `operator -> dodns : M13 +trace`; Trace section says it walks from the root. Label fix.                                                 |
| B8/B9/E8 History row order, date and phrasing (blind, edge)  | low         | patch  | Row dated 2026-10-22 sits before the 18:10 deletion row and states the 2026-10-28 runbook change; "the A record goes" is not a sentence.          |
| B6 new M13 drops public DNS and HTTPS re-check (blind)       | false       | reject | Deleting an occluded record changes no answer; M12 verified HTTPS and M14 Verify re-checks Google and Cloudflare after the deletion.              |
| B10 item 38 set done while spec in review (blind)            | false       | reject | The spec's task list sets it done; the user approves at the checkpoint and commits. Fix would edit this build's spec.                             |
| B11 retro line 125 and AGENTS.md quote the old wait (blind)  | false       | reject | Both are dated history: the retro records the deviation as found, the AGENTS.md pitfall uses the past tense. Item 38 in sprint-status links them. |
| E2 one query may hit an un-updated KAS instance (edge)       | maybe-false | defer  | If true, medium: all-inkl quotes 3–4 h propagation. Settled by whether ns5/ns6 are anycast with independent zone copies and ordered updates.      |
| E6 Cached Wildcard section implies a TTL gate (edge)         | false       | reject | `dns-delegation.md:330` is about names cached before M10 and says the A record stays until M14; it sets no time gate on M14.                      |
| E7 as-built does not meet "re-checked right before" (edge)   | false       | reject | M11 at 18:06–18:07 UTC, deletion at 18:10:02 UTC, no KAS change in between: within the 10-minute bound now written into the AC.                   |

## Verification

**Commands:**

- `task lint` -- expected: pass (markdown-links / lychee, yaml).
- `grep -n -E 'M13|Two TTLs|2 x TTL|twice the KAS TTL' docs/cloud/digital-ocean/dns-delegation.md _bmad-output/planning-artifacts/epics-fantasy-hockey-digitalocean.md` -- expected: no hit that requires the wait; M13 mentions are the renamed step.

**Manual checks (if no CLI):**

- `task docs:run`: diagram C renders and the M13/M14 anchors from `domain.md` resolve.
