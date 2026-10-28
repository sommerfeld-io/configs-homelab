---
title: 'Story 6.1: Molecule check that the cloud Alloy config has no Wi-Fi collector'
type: 'chore'
created: '2026-10-28'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The cloud `alloy` Molecule verify (`configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml`) does not assert that the rendered droplet Alloy config has no `wifi` collector, so copying `enable_collectors = ["wifi"]` from the fleet template into `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` passes `molecule-cloud` (Epic 9 retro item 44, finding C1).

**Approach:** Add `'wifi' not in alloy_config` to the existing cloud-config assert in that verify, so `task cloud:molecule:test:alloy` and the `molecule-cloud` CI job fail when the rendered config mentions a `wifi` collector. Update the `alloy` row in `docs/cloud/digital-ocean/tests.md`. Delete the three `deferred-work.md` entries Story 6.1 closes: the spec-8-1 `tofu test` entry, the cloud `alloy` Molecule assert entry and the combined fleet line and Git Sync note (both under "Deferred from: code review of spec-9-1 and spec-9-2").

Decisions (user, 2026-10-28): no `tofu test` with `mock_provider`, no vault-free playbook syntax or collection pin check (to be tested later against the real provisioned infrastructure, InSpec is the candidate), no fleet template check and no change to `alloy validate`, no Git Sync manifest check, no dynamic inventory check. The spec-9-1 fleet Wi-Fi entry and the spec-9-2 Git Sync entry in `deferred-work.md` stay. Work on `main`, no commit until the user allows it.

</frozen-after-approval>

## Implementation Notes

- `configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml`: new task "Assert the cloud config has no wifi collector" after the label assert: `'wifi' not in alloy_config` with a `fail_msg` that names the cloud template. A plain substring check, like the `github` and `remotecfg` checks, so a `wifi { ... }` block fails as well as `enable_collectors = ["wifi"]`; the cloud template mentions `wifi` nowhere today. First built as a line in the label task; moved into its own task after review.
- `docs/cloud/digital-ocean/tests.md`: the `alloy` row of the Scenarios table says the config does not contain the text `github`, `remotecfg` or `wifi`; table width unchanged.
- `configs-homelab/ansible/roles/grafana-cloud/alloy/README.md` (and its copy `docs/homelab/ansible/roles/grafana-cloud/alloy.md` from `task docs:generate`): names the cloud `alloy` Molecule verify as the guard.
- `_bmad-output/implementation-artifacts/deferred-work.md`: deleted the spec-8-1 `tofu test` entry and both entries under "Deferred from: code review of spec-9-1 and spec-9-2", and the then empty heading. The spec-9-1 fleet Wi-Fi entry stays, reworded to the fleet half only; the spec-9-2 Git Sync entry stays.
- Sprint status: Story 6.1 and Epic 6 set to `in-progress`, then Story 6.1 to `review`.
- Checks (2026-10-28, after the review fixes): `task cloud:molecule:test:alloy` passed (7 of 8 actions successful, no failures). Mutation run: `sed -i 's/^prometheus.exporter.unix "integrations_node_exporter" {$/&\n  enable_collectors  = ["wifi"]/' configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`, then `task cloud:molecule:test:alloy`: verify failed on the new task with its `fail_msg`; the template was restored from a scratch copy (`git status` clean for it). `task lint` exit 0.

## Review Triage Log

Blind Hunter, pass 1 (12 findings):

- low, patch — the `alloy` row in `tests.md` was 1097 characters, the rest of the table 1073: reworded the cell, the table is 1073 wide again.
- low, patch — "block and no `wifi` collector" read badly: folded into the reworded cell.
- low, patch — the doc said "no `wifi` collector" while the assert bans the substring: the doc now says the config does not contain the text `wifi`; the substring ban is kept on purpose (catches a `wifi { }` block too).
- low, patch — the assert sat in the label task without its own name or `fail_msg`, under a comment that read as if the label checks were Story 6.1's: own task with `fail_msg`.
- low, patch — the comment's reason ("the droplet has no Wi-Fi interface") is weak, since the role README says a node without Wi-Fi sends no `node_wifi_*` series: the comment now says the collector is fleet-only (Epic 9 retro item 44).
- medium, patch — the kept spec-9-1 deferred entry pointed at a deleted "separate entry below" and still called the cloud half unguarded: reworded to the fleet half only.
- false — "deleting the spec-8-1 `tofu test` entry drops an open gap": the user ordered the deletion; the follow-up (InSpec against the real infrastructure) is recorded in the Story 6.1 text in `epics-fantasy-hockey-digitalocean.md` and in `stories.yaml`.
- false — "the `prevent_destroy` check has nowhere to live": its entry is still in `deferred-work.md` (line 14), untouched by this change.
- false — "the spec has no acceptance criteria or verification section": the oneshot route keeps only Intent and Implementation Notes by design; the checks are in the notes and the status is set to done at finalize.
- low, patch — the mutation run was prose only: the exact command is now in the notes.
- low, patch — the role README did not name the guard: one sentence added, docs copy regenerated.
- low, reject — `epic-6-context.md` does not list its source files: generated by the build workflow's own template; regenerated when planning docs are newer, so drift is detected by timestamp, not by a source list.
