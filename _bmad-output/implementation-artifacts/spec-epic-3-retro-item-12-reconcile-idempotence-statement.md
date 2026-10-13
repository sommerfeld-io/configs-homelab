---
title: 'Reconcile the provisioning idempotence statement with the per-run Alloy restart'
type: 'chore'
created: '2026-10-13'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The planning docs say a second provisioning run changes nothing (`epic-3-context.md`, the Story 3.1 acceptance criterion, `SPEC.md` CAP-2). Story 3.2 deliberately accepted that the fleet Alloy role reports changes on every run (forced template, `state: restarted`), so the cloud config copy and the Alloy restart report changed too (Epic 3 retro finding 10, action item 12).

**Approach:** State the exception in every planning doc that makes the claim: everything else changes nothing on a second run, while the fleet Alloy part reports changed on every run until retro item 8 (stop fleet-only side effects) lands. Story 3.4's second-run criterion is scoped to the MOTD. Finished story specs stay as the historical record.

</frozen-after-approval>

## Implementation Notes

- Changed: `epic-3-context.md` (Requirements & Constraints), the epics file (Story 3.1 second-run criterion; Story 3.4 second-run criterion scoped to "the MOTD tasks report no change"), `SPEC.md` (CAP-2 success).
- Cause, checked in `configs-homelab/ansible/roles/grafana-cloud/alloy/tasks/main.yml`: `force: true` alone does not report a change. The fleet template reports changed because the previous run replaced `config.alloy` with the cloud config. The `systemd` task with `state: restarted` reports changed every time. The first wording ("forced fleet template") was corrected before review.
- Not changed: the finished `spec-3-1-…` (frozen intent and its `changed=0` acceptance criterion) stays the historical record of what was approved. `docs/cloud/digital-ocean/provisioning.md` already describes the per-run changes.
- After review: the exception names the four tasks and splits the cause into its own sentence, the item reference cites retro action 1 and the sprint-status id `epic-3-retro-item-8-…` (the retro document numbers its actions differently), and the same wrong cause ("forced template") is fixed in `docs/cloud/digital-ocean/provisioning.md`. Story 3.4's second-run criterion is narrowed to the MOTD tasks on purpose; `sprint-change-proposal-2026-10-13.md` keeps the old wording as history. `task lint` exit 0.
- Approval: the user owns item 12 and asked for it in this build (`/bmad-build items 12 and 13`).
- Retro item 13 (second provision run, `grafana-agents.yml` rollout) is not part of this spec: both need the vault password, the fleet rollout also needs the become password, and the task is host-only. The user runs it.


## Review Triage Log

- Retro numbers don't match the retro document (item 8 vs action 1): medium, patched. References now give retro action 1 and the sprint-status id.
- Frozen Intent still says "forced template": low, not patched. The frozen block is human-owned; the Implementation Notes record the correct cause.
- `provisioning.md` carries the same wrong cause: low, patched.
- Exception understates the twice-per-run restart and the brief fleet config: low, rejected. Already in `provisioning.md` ("the few seconds the fleet config runs") and in retro finding 1; the planning docs state what a second run reports.
- Story 3.1 criterion doesn't name the tasks: medium, patched. The four task names are listed; other fleet-role tasks fall under "nothing changes".
- "Everything else changes nothing" never observed: false. Acceptance criteria state the expected result; observing it is retro item 13, which is still open.
- Nothing ensures the exception gets removed: medium, deferred (it would edit item 8's tracking and the specs).
- Story 3.4 narrowed silently: low, patched in the Implementation Notes.
- No sources linked, no lint recorded: low, patched (lint recorded; sources are named in the Intent).
- Tracking not updated, approval not recorded: low, patched. Item 12 set to done; approval noted.
- New sentences hard to read: low, patched with the task-naming fix.
