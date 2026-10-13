---
date: 2026-10-13
trigger: epic-3-retro-item-15
mode: incremental
scope: moderate
status: approved
approved: 2026-10-13
---

# Sprint Change Proposal: Molecule Tests for the Cloud Ansible Roles

## 1. Issue Summary

The Epic 3 retrospective (`implementation-artifacts/epic-3-retro-2026-10-13.md`, finding 9, action item 15) found that nothing tests the cloud roles automatically. A broken role path, a wrong label value or a broken `20-updates` parser only fails against the live droplet. Stories 3.1, 3.2 and 3.4 each deferred the check, so it is a process issue now.

- **Type:** a new requirement from the retro, plus a process gap.
- **Evidence:** five related entries in `deferred-work.md`. The build of retro items 9, 11 and 16 on 2026-10-13 also showed that `provision.yml` cannot be syntax-checked without the vault password.
- **Requested by the user:**
    - Molecule scenarios for all cloud roles under `configs-cloud/digital-ocean/tests/molecule`.
    - A taskfile there that the root taskfile includes.
    - A job in `pipeline.yml`.
    - A rule in `CLAUDE.md` that new Ansible roles need Molecule tests.

## 2. Impact Analysis

### Epic Impact

| Epic   | Impact                                                                                                  |
|--------|---------------------------------------------------------------------------------------------------------|
| Epic 3 | New Story 3.5. The epic stays `in-progress` until 3.5 is done; the retrospective stays `done`.          |
| Epic 4 | Story 4.1 must bring a Molecule scenario for the moved `fantasy-hockey` role (new rule).                |
| Epic 5 | None.                                                                                                   |
| Epic 6 | Story 6.1 takes over the parts of item 15 that are not Molecule tests (syntax check, pin completeness). |

### Story Impact

- **Story 3.5 (new):** one scenario per cloud role, a shared base and prepare, a taskfile, a CI job, the `CLAUDE.md` rule and docs.
- **Story 4.1:** one more acceptance criterion. The role's fully vault-encrypted `defaults/main.yml` has to be split, so the scenario runs without the vault password.
- **Story 6.1:** two more acceptance criteria.

### Artifact Conflicts

- **PRD:** no conflict. The change supports FR6 (the same task entry points locally and in CI).
- **Architecture:** AD-8 forbids applying playbooks to containerized targets in this repo's CI. The existing `molecule` job already contradicts it (listed as deferred). AD-8 gets a role-test carve-out.
- **UX:** none, there are no UX documents.

### Technical Impact

- New `configs-cloud/digital-ocean/tests/molecule/` tree, new `molecule-cloud` job in `pipeline.yml`, new `molecule-cloud` include in the root taskfile, `.folderslintrc` rules, docs under `docs/cloud/digital-ocean`.
- Container limits that shape the scenarios:
    - A container cannot enable swap and must not change the runner's swap, so `swapon` is stubbed.
    - `alloy-config` restarts Alloy through systemd, so its scenario needs a systemd container.
- The roles themselves stay unchanged.

## 3. Recommended Approach

**Direct adjustment:** add Story 3.5 to Epic 3, amend Stories 4.1 and 6.1, and amend AD-8.

- **Rationale:** the roles under test are Epic 3's, and Epic 3 is still open in sprint status. Landing the harness before Story 4.1 means the first new role already follows the rule.
- **Effort:** medium (3 scenarios, CI job, taskfile, docs).
- **Risk:** low to medium. The systemd container and the swap stub are the only non-standard parts.
- **Timeline:** one story ahead of Epic 4. No epic is reordered.
- **Rejected alternatives:**
    - Rollback: there is nothing to revert.
    - MVP review: the MVP is unchanged.
    - Story in Epic 6: it would land after Story 4.1 adds a role.
    - Story 4.0: it would leave the Epic 3 roles' gap in Epic 3's own tracking.

## 4. Detailed Change Proposals

All six proposals were approved one by one.

### 4.1 Epics: New Story 3.5

`planning-artifacts/epics-fantasy-hockey-digitalocean.md`, inserted after Story 3.4:

```markdown
### Story 3.5: Molecule tests for the cloud Ansible roles

As an operator,
I want every cloud role tested in a container,
So that a broken role fails in CI instead of on the droplet.

**Acceptance Criteria:**

**Given** the cloud roles `swap`, `alloy-config` and `motd`
**When** I run `task molecule-cloud:test`
**Then** one Molecule scenario per role under `configs-cloud/digital-ocean/tests/molecule/<role>/molecule/default/` runs converge, idempotence and verify on Ubuntu 26.04 (the droplet image), using a shared `base.yml` and `prepare.yml` in `configs-cloud/digital-ocean/tests/molecule/`
**And** `task molecule-cloud:test:<role>` runs a single scenario from `configs-cloud/digital-ocean/tests/molecule/taskfile.yml`, which the root taskfile includes as `molecule-cloud`

**Given** a container cannot enable swap and must not touch the CI runner's swap
**When** the `swap` scenario runs
**Then** `prepare` replaces `swapon` with a stub that records the activated file, so the role runs unchanged
**And** verify asserts the file size, mode `0600`, the `mkswap` signature and the `/etc/fstab` line, and idempotence proves the second run changes nothing

**Given** `alloy-config` restarts Alloy through systemd and reads facts the fleet Alloy role sets
**When** the `alloy-config` scenario runs
**Then** it runs in a container with systemd and a dummy `alloy.service`, and converge sets `alloy_config_dir`, `alloy_group`, `alloy_service_name`, `alloy_environment` and `alloy_stage`
**And** verify asserts that `config.alloy` carries `environment = "digital-ocean"` and `stage = "prod"` in both `external_labels` blocks and has no `github` or `remotecfg` block

**Given** the `motd` scenario
**When** verify runs the scripts in `/etc/update-motd.d`
**Then** fixtures for the update stamp cover zero, one and several pending updates and check the exact `20-updates` output
**And** only `00-banner`, `10-os-line`, `20-updates` and `98-reboot-required` are executable

**Given** a pull request
**When** `pipeline.yml` runs
**Then** a `molecule-cloud` job runs every cloud scenario as a matrix, after linting, and gates the docs and release stages like the `molecule` job
**And** `CLAUDE.md` says a new Ansible role in this repo (local homelab roles and `configs-cloud/*/ansible/roles`) is not done without a Molecule scenario, while submodule roles are tested in the submodule
**And** the docs under `docs/cloud/digital-ocean` describe the scenarios and the tasks
```

### 4.2 Spec and Epic Context: Mirror Story 3.5

`specs/spec-fantasy-hockey-digitalocean/stories.yaml`, inserted after `id: "8a"`:

```yaml
- id: "8b"
  title: Molecule tests for the cloud Ansible roles
  description: >-
    Add one Molecule scenario per cloud role (swap, alloy-config, motd) under configs-cloud/digital-ocean/tests/molecule/<role>/molecule/default/ with a shared base.yml (Ubuntu 26.04) and prepare.yml, run by configs-cloud/digital-ocean/tests/molecule/taskfile.yml, included in the root taskfile as molecule-cloud (CAP-6).
    Add a molecule-cloud matrix job to pipeline.yml that gates docs and release like the molecule job, and state in CLAUDE.md that a new Ansible role in this repo needs a Molecule scenario (submodule roles are tested in the submodule).
    Docs updated in the same change.
  invoke_dev_with: >-
    The roles stay unchanged for the tests. A container cannot enable swap and must not touch the runner's swap, so prepare stubs swapon for the swap scenario. alloy-config needs a systemd container with a dummy alloy.service and the facts the fleet Alloy role sets (alloy_config_dir, alloy_group, alloy_service_name) plus alloy_environment and alloy_stage.
    Verify the rendered labels in config.alloy, the absence of github and remotecfg blocks, and the 20-updates output against stamp fixtures (zero, one, several updates).
    Allow the new folders in .folderslintrc and keep the pipeline matrix in sync with the taskfile. The provision.yml syntax check is not part of this story (Story 6.1).
```

`implementation-artifacts/epic-3-context.md`:

- **Stories**, after the 3.4 line: `- Story 3.5: Molecule tests for the cloud Ansible roles`
- **Requirements & Constraints**, after the linters bullet: `- Every cloud role has a Molecule scenario under configs-cloud/digital-ocean/tests/molecule, run locally through task molecule-cloud:* and in CI by the molecule-cloud job.`
- **Cross-Story Dependencies**, after the 3.2/3.3 line: `- Story 3.5 tests the roles from Stories 3.2 (swap, alloy-config) and 3.4 (motd) and sets the rule that every later role, starting with Story 4.1, comes with a scenario.`

### 4.3 Story 4.1: Scenario for the Moved Role

Epics file, Story 4.1, a new criterion after the vault and Dependabot criterion:

```markdown
**Given** the moved role and the rule from Story 3.5
**When** I run `task molecule-cloud:test:fantasy-hockey`
**Then** a Molecule scenario for the role runs converge, idempotence and verify without the vault password
**And** the `molecule-cloud` matrix in `pipeline.yml` and the taskfile include it
```

`stories.yaml`, `id: "9"`, appended to `invoke_dev_with`:

```text
Add a Molecule scenario for the moved role (rule from 8b). Its defaults/main.yml is fully vault-encrypted, which a scenario cannot load without the vault password, so move the secrets out of the role defaults into a vault file the deploy playbook loads, keep plain defaults in the role, and give the scenario test values. Do not add the vault password to the pull-request CI. The container cannot run Docker itself, so the scenario verifies the user, files, templates and the seed-only-when-absent rule; starting the containers is verified on the droplet.
```

### 4.4 Story 6.1: The Rest of Item 15

Epics file, Story 6.1, new criteria:

```markdown
**Given** `provision.yml` and every cloud playbook
**When** CI runs
**Then** each playbook passes `ansible-playbook --syntax-check` without the vault password (for example by moving the vault-free parts into imported playbooks, or giving the check a dummy vault file)
**And** a check fails when a cloud playbook uses a collection that is not pinned in `configs-cloud/digital-ocean/ansible/requirements.yml`
```

`stories.yaml`, the Story 6.1 entry, appended to its description:

```text
Also covers the parts of epic-3 retro item 15 that are not Molecule tests: a vault-free syntax check of the cloud playbooks and a check that every collection they use is pinned in requirements.yml (see deferred-work.md).
```

### 4.5 Architecture: AD-8 Role-Test Carve-Out

`planning-artifacts/architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md`:

- **Rule:** "Multi-Ubuntu-version role-level testing is owned exclusively by the `ansible-roles-collection` submodule's own CI." becomes "… role-level testing of submodule roles is owned exclusively …", followed by:

    ```text
    *Carve-out (role tests):* roles this repo owns — local homelab roles under `configs-homelab/ansible/roles/{common,grafana-cloud,media}` and cloud roles under `configs-cloud/*/ansible/roles` — are tested with Molecule in containers by this repo's CI (`molecule` and `molecule-cloud` jobs, scenarios under `configs-homelab/tests/molecule` and `configs-cloud/*/tests/molecule`). Every new repo-owned role needs a scenario. Submodule roles are never re-tested here, and fleet playbooks are still never applied.
    ```

    The existing cloud carve-out is renamed "*Carve-out (cloud deploy):*".
- **Binds:** add `configs-homelab/tests/molecule/*` and `configs-cloud/*/tests/molecule/*`.
- **Deferred list:** remove "AD-8 versus the existing `molecule` CI job".

### 4.6 Sprint Status

`implementation-artifacts/sprint-status.yaml`:

- Add `3-5-molecule-tests-for-the-cloud-ansible-roles: backlog` after Story 3.4. `epic-3` stays `in-progress`, and `epic-3-retrospective` stays `done`.
- Set `epic-3-retro-item-15-plan-a-cloud-test-harness-story-provisio` to `done`: the plan is this proposal, and the work is tracked by Story 3.5.
- `last_updated` comes from `sprint_status.py` and `date`, never written by hand.

## 5. Implementation Handoff

- **Scope:** moderate. It changes the backlog (a new story and two amended stories) and amends one architecture decision, without a replan.
- **This workflow:** after approval, apply the planning edits from 4.1 to 4.6.
- **Developer (`bmad-build`, fresh context):** build Story 3.5 with "story 3-5". The `CLAUDE.md` rule (in `.github/copilot-instructions.md`, which `CLAUDE.md` links to), the `molecule-cloud` taskfile include, the CI job and the scenarios are all built in that story.
- **Later stories:** Story 4.1 and Story 6.1 pick up their amended criteria when they are built.
- **Success criteria:**
    - `task molecule-cloud:test` passes locally for `swap`, `alloy-config` and `motd`, including idempotence.
    - The `molecule-cloud` job passes in `pipeline.yml` and gates docs and release.
    - `task lint` passes with the new folders.
    - `CLAUDE.md` states the rule.
    - No cloud role was changed to make a test pass.
