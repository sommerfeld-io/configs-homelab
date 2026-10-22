---
title: 'Epic 8 retro item 39: reconcile Story 6.1 and deferred work with the OpenTofu checks already in CI'
type: 'chore'
created: '2026-10-22'
status: 'done'
baseline_commit: 'ba9cc5d64f4ee1f06308c07ba9c67521a2f236fe'
route: 'oneshot'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-8-retro-2026-10-22.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Three off-story commits in the Epic 8 range already deliver part of Story 6.1. `63fabb4` puts `tofu validate` in `task lint`. `3e90479` and `a96b137` add the `validate-opentofu` CI job, and item 35 (`6da3d31`) made the local validate work without a manual init. The planning docs still describe that work as open (Epic 8 retro, finding A2, action item 39):

- Story 6.1 in `epics-fantasy-hockey-digitalocean.md` and in the spec folder's `stories.yaml` (entry `"14"`);
- the `deferred-work.md` entry from Story 2.4 that asks for exactly these checks;
- the Story 8.1 entries.

Story 6.1 would then re-implement existing checks. Meanwhile the gap that remains, plan-level tests of `dns.tf`, is named nowhere in the story.

**Approach:** Planning docs only.

- Story 6.1 keeps its title and its sprint-status key (`6-1-ci-static-checks-for-opentofu-and-ansible`).
- Its OpenTofu acceptance criterion is narrowed: `fmt -check` and `validate` already run in `task lint` and CI, so the remaining OpenTofu work is a `tofu test` plan test with `mock_provider`. That test covers the `dns.tf` record derivation, the four preconditions and the CAA issuer set.
- The Ansible criteria stay unchanged.
- In `deferred-work.md`, the resolved entries are deleted, following the precedent of `527c6f1`:
    - the Story 2.4 validate entry;
    - the Story 8.1 ZeroSSL entry, resolved by M8a in `760f82d`;
    - the Story 8.1 CAA trailing-dot entry, settled by M5.
- The Story 8.1 CI entry is narrowed to the plan test, following the in-place precedent of `c237c74`.
- The finished Story 8.1 and 8.2 specs and their triage logs stay as they are: they are history.

</frozen-after-approval>

## Implementation Notes

- `epics-fantasy-hockey-digitalocean.md` Story 6.1: the first acceptance criterion ("OpenTofu and Ansible checks run the same way as locally") is replaced by a note on the checks that already run (with commits) and a `tofu test` plus `mock_provider` criterion for `dns.tf`. Title and both Ansible criteria are unchanged, so the sprint-status key stays valid.
- `stories.yaml` entry `"14"`: one description line added with the same narrowing; the file still parses.
- `deferred-work.md`: deleted the Story 2.4 validate entry and the Story 8.1 ZeroSSL and CAA trailing-dot entries; rewrote the Story 8.1 CI entry to the remaining plan-test gap. Other entries untouched.
- Not changed: the done Story 8.1/8.2 specs and triage logs (history), the Story 2.2/2.4 pin-sync entry whose evidence still says a version other than 1.12.7 fails `init`/`plan` (disproved in item 35, already tracked by the item 35 deferred entry), and CI calling the task entry points (item 36).
- Correction: both precedents named in the Intent are in `527c6f1` (it deleted resolved entries and narrowed the Story 2.3 entry in place, "The devcontainer half of this entry was fixed in `6f8671f`"); `c237c74` only added entries.

## Review Triage Log

Blind Hunter, 11 findings:

- medium, patch — the new 6.1 criterion asks `tofu test` to feed bad inputs, but the `droplets` map, `dns_external_records` and `dns_caa_issuers` are `locals` (`droplets.tf:40`, `dns.tf:1`), which `tofu test` cannot override; the criterion now requires making them injectable first.
- medium, patch — the stage precondition in `droplets.tf:93` is a fifth plan-time guard left out of "the four preconditions"; criterion, `stories.yaml` and the deferred entry now name five.
- medium, patch — "the CAA records for every entry of `dns_caa_issuers`" only restates the `for_each` and passes for any list; now the exact set `letsencrypt.org.`, `sectigo.com.`, `0 issue`, TTL 3600.
- low, patch — the note said `fmt -check` runs in `validate-opentofu`; it runs in the CI lint matrix (`lint-opentofu`).
- low, patch — the checks were attributed to item 39; now finding A2 and item 35, with item 39 as the re-scope.
- low, patch — the narrowed deferred entry and the 6.1 criterion describe the same work without a cross-reference; the entry now says so and when to delete it.
- low, reject — `stories.yaml` "14" still opens with "Run the new linters and static checks … the same way as today"; still true for the Ansible part, and the added line states the OpenTofu scope.
- low, reject — other Epic 6 deferred entries (`prevent_destroy`, `do_tags` "fits Story 6.1") not folded in; outside this item's intent (they need real state or a token/fixture by their own evidence).
- low, reject — item 39 not marked `done` in `sprint-status.yaml`; the operator decides that after review, as for item 35.
- low, reject — the Story 2.2/2.4 pin-sync entry still claims another version fails `init`/`plan`; pre-existing, and the item 35 deferred entry already records the disproof.
- low, reject — the Intent cites `c237c74` as the in-place precedent; the fix edits the frozen block; corrected in Implementation Notes above.
