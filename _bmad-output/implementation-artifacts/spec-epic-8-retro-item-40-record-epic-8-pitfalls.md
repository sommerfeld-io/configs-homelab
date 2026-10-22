---
title: 'Epic 8 retro item 40: record the Epic 8 process lessons as project pitfalls'
type: 'chore'
created: '2026-10-22'
status: 'done'
baseline_commit: 'ce653c70365e6e9a382cec4e7cd338e795744fd3'
route: 'oneshot'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-8-retro-2026-10-22.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Epic 8 retro found two process lessons that no pitfall covers yet (findings P1 and P2, action item 40):

- **Off-story work skipped the story loop:** three commits added `tofu validate` to `task lint` and CI without a story, spec or review: `63fabb4`, `3e90479` and `a96b137`. They closed part of a deferred item and of Story 6.1, but updated neither. They also carried defects that only the retro found (R1 to R5).
- **The runbook named only a duration for its wait:** runbook step M13 said only "wait 2 × 7200 s". The operator skipped it safely because the protected condition was already observable, but the runbook never names that condition.

**Approach:** Append two bullets to "Known pitfalls" in `AGENTS.md`, inside the `bmad:context` block, in the style of the existing bullets: an imperative rule followed by the concrete Epic 8 evidence with commits. This follows the precedent of `864e7ce` and `4268e20`. No other file changes. Marking item 40 `done` in `sprint-status.yaml` is left to the operator.

</frozen-after-approval>

## Implementation Notes

- `AGENTS.md`: two bullets appended at the end of "Known pitfalls", inside the `bmad:context` block (P1 off-story work, P2 runbook waits). The block header ("Verified 2026-10-15 against c300f3c") is left as is, like `864e7ce` did.
- Checked each bullet's facts against the retro (A1, A2, R1, R2), the commits (`63fabb4`, `3e90479`, `a96b137`, `6da3d31`, `688345c`) and `dns-delegation.md` M13/M14 before committing.
- Correction: the Intent's paraphrase of M13 ("wait 2 × 7200 s") is loose; the runbook says "wait at least 4 hours (2 × the KAS TTL of 7200 s) after M10, ideally 24 hours. Then repeat M11 and M12 once", which the `AGENTS.md` bullet quotes.

## Review Triage Log

Blind Hunter, 8 findings:

- medium, patch — pitfall 2 said M13 "gives no check that shows the wait is over", but M13 repeats M11 and M12; the real gap is that M14 is gated on elapsed time and M13's reason is not observable. Reworded.
- low, patch — the evidence was in the present tense and will go stale once items 38 and 39 land; now past tense, naming the fixes `688345c` and `6da3d31`, like the older bullets.
- low, patch — pitfall 1 cited R1 to R5 but described only R1 and R2; the citation is narrowed to A2, R1 and R2.
- low, patch — pitfall 2 addressed the operator during a run; it now tells whoever writes or reviews a runbook to gate the next step on the check (merged with the finding about who it applies to).
- low, reject — item 40 not marked `done` in `sprint-status.yaml` although `864e7ce` closed its items in the same commit; the operator closes retro items separately on this branch (`ba9cc5d`, `ce653c7`).
- false — "no acceptance check or triage log": this one-shot spec records the fact check and this log, and its status is set to `done` at finalize.
- low, reject — the spec misquotes M13; the fix edits the frozen block; corrected in Implementation Notes.
- low, reject — the bullets sit in the `bmad:context` block that a refresh replaces; every earlier pitfall lives there (`864e7ce`, `4268e20`), and the managing skill records pitfalls in that block.
