---
title: 'Molecule tests for the cloud Ansible roles'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_commit: 'c3da9d4fc6fcededbc42eaf5170619b4c37e0b9f'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The roles the droplet runs (`swap`, `motd` and the fleet Alloy role with `alloy_fleet_extras: false` and the cloud template) have no automated test, so a broken role is only found on the droplet (Story 3.5, deferred findings of Stories 3.2 and 3.4).

**Approach:** Add one Molecule scenario per role under `configs-cloud/digital-ocean/tests/molecule/<role>/molecule/default/`, each running converge, idempotence and verify on Ubuntu 26.04, plus a shared `base.yml` and `prepare.yml`, go-task entry points (`task molecule-cloud:test`, `task molecule-cloud:test:<role>`), a `molecule-cloud` CI matrix job, the "every role needs a scenario" rule in the agent instructions, and docs.

## Boundaries & Constraints

**Always:** Scenarios `motd` and `alloy` (human decision 2026-10-13: tests stay simple and must never break the host; `swap` gets no scenario because `swapon` needs a privileged container). Test containers are plain `ubuntu:26.04`, unprivileged, without host mounts and without systemd; a `systemctl` stub in `prepare.yml` answers the Alloy role's service calls. Test sequence like the homelab `base.yml` (dependency, destroy, create, prepare, converge, idempotence, verify, destroy). Roles run unchanged; test-only setup goes into `prepare.yml` or converge `pre_tasks`. The `alloy` scenario uses the cloud template `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`, `alloy_environment: digital-ocean`, `alloy_stage: prod` and fake Grafana Cloud secrets; no vault password anywhere. Collections come from the pinned `configs-cloud/digital-ocean/ansible/requirements.yml`. `molecule-cloud` runs after `lint`, `shellcheck`, `check-inspec-profile`, with `fail-fast: false`, and `generate-docs` needs it like `molecule`. The rule: a new Ansible role in this repo (local homelab roles and `configs-cloud/*/ansible/roles`) is not done without a Molecule scenario; submodule roles are tested in the submodule. Docs under `docs/cloud/digital-ocean` describe scenarios and tasks. Run every command the docs show once first; all linters pass.

**Never:** No change to role code, `provision.yml` or the Alloy templates. No test against the droplet. No privileged container, no systemd as PID 1, no host mounts. No Arch platform (the droplet is Ubuntu only).

## I/O & Edge-Case Matrix

| Scenario                 | Input / State                                               | Expected Output / Behavior                                                                                                                        | Error Handling        |
|--------------------------|-------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|
| motd, zero updates       | Stamp with `0 updates can be applied immediately.` and ESM lines | `20-updates` prints nothing                                                                                                                   | Assert fails the test |
| motd, one update         | Stamp with `1 update can be applied immediately.` + hint    | Exactly `1 update can be applied immediately.\nTo see these additional updates run: apt list --upgradable\n\n`                                  | Assert fails the test |
| motd, several updates    | Real droplet stamp (12 updates, ESM lines around)           | Exactly the count line, the hint line and one blank line; no ESM line                                                                              | Assert fails the test |
| motd exec bits           | Converged                                                   | Executable in `/etc/update-motd.d`: exactly `00-banner`, `10-os-line`, `20-updates`, `98-reboot-required`                                         | Assert fails the test |
| alloy verify             | Converged                                                   | No `/etc/alloy/github.token`, `getcap /usr/bin/alloy` empty, `config.alloy` has `environment = "digital-ocean"` and `stage = "prod"` twice each, no `github` or `remotecfg` | Assert fails the test |
| idempotence (all)        | Second converge                                             | `changed=0`                                                                                                                                       | Molecule fails        |

</frozen-after-approval>

## Code Map

- `configs-homelab/tests/molecule/{base,prepare,taskfile}.yml`, `common/molecule/default/*` -- pattern to copy: `MOLECULE_CMD` with `--base-config ../base.yml`, galaxy dependency from `${MOLECULE_SCENARIO_DIRECTORY}/../../../../..` (5 ups = `configs-cloud/digital-ocean`), `playbooks.prepare: ../../../prepare.yml`. Do not change the homelab harness.
- `configs-cloud/digital-ocean/ansible/roles/motd` -- role under test. `configs-homelab/ansible/roles/grafana-cloud/alloy` -- Alloy role. Converge references both by path relative to the playbook (like `provision.yml`), so ansible-lint, which lints `configs-cloud`, resolves them; no `ANSIBLE_ROLES_PATH`. It downloads from `apt.grafana.com`, uses `getcap`, a cron entry for `default_user`, adds user `alloy` to group `docker`, manages the service through `ansible.builtin.systemd` (answered by the `systemctl` stub), has `become: true` tasks (needs `sudo`), `apt_repository` (needs `gpg`).
- `configs-cloud/digital-ocean/ansible/vars/main.yml` -- sets `alloy_config_template` with `playbook_dir`; in Molecule `playbook_dir` is the scenario dir, so converge sets `"{{ playbook_dir }}/../../../../../ansible/templates/alloy/config.alloy.j2"` and `default_user: root`, `alloy_fleet_extras: false`, and the `grafana_cloud_*` secrets the env file reads.
- Platform: one platform `ubuntu-26.04` (`image: ubuntu:26.04`, `pre_build_image: true`) in the shared `base.yml`. systemd does not boot unprivileged (`Failed to set RLIMIT_CORE: Operation not permitted`), so the Alloy role's service calls go to a stub `/usr/local/bin/systemctl` (before `/usr/bin` in PATH).
- `prepare.yml` -- install `python3` (raw), then what the droplet image has and the image lacks: `ca-certificates`, `python3-apt`, `cron`, `libcap2-bin`, `gnupg`, `sudo`, `landscape-common` (else the motd debconf task is not idempotent, see 3.4 triage), `update-notifier-common` (ships `98-reboot-required`); create group `docker`; install the `systemctl` stub. Droplet facts (read-only SSH): page size 4096, those packages installed. The Docker image's `/etc/update-motd.d` has `00-header`, `10-help-text`, `50-motd-news`, `60-unminimize`.
- Real stamp (`/var/lib/update-notifier/updates-available` on the droplet), use it as the several-updates fixture: blank, `Expanded Security Maintenance for Applications is not enabled.`, blank, `12 updates can be applied immediately.`, `To see these additional updates run: apt list --upgradable`, blank, `Enable ESM Apps to receive additional future security updates.`, `See https://ubuntu.com/esm or run: sudo pro status`, blank.
- `taskfile.yml` (root) -- include `molecule-cloud` with `dir: configs-cloud/digital-ocean/tests/molecule`.
- `.github/workflows/pipeline.yml` -- copy the `molecule` job as `molecule-cloud` (matrix `motd`, `alloy`, comment "keep in sync with the taskfile"); `generate-docs.needs` gets it.
- `.folderslintrc` -- add `configs-cloud/*/tests/molecule/**`. ansible-lint lints `molecule/` playbooks.
- `.github/copilot-instructions.md` (`CLAUDE.md` is a symlink to it) -- Testing section: add the cloud harness and the rule; its line "tests Ansible roles from `ansible-roles-collection`" contradicts `docs/ansible/molecule.md`, correct it in the same edit.
- Docs: new `docs/cloud/digital-ocean/tests.md` (+ `mkdocs.yml` nav), `tasks-and-linters.md` (tree, task rows, folderslint row), `docs/pipelines.md` (job list, needs order), `docs/ansible/molecule.md` (pointer to the cloud scenarios).

## Tasks & Acceptance

**Execution:**
- [x] `configs-cloud/digital-ocean/tests/molecule/{base.yml,prepare.yml,taskfile.yml}` -- shared harness and tasks `test`, `test:motd`, `test:alloy` -- one entry point per scenario
- [x] `configs-cloud/digital-ocean/tests/molecule/{motd,alloy}/molecule/default/{molecule,converge,verify}.yml` -- scenarios per the I/O matrix -- role coverage
- [x] `taskfile.yml`, `.folderslintrc` -- include and folder rule -- wiring and lint
- [x] `.github/workflows/pipeline.yml` -- `molecule-cloud` job, `generate-docs` gate -- CI
- [x] `.github/copilot-instructions.md` -- cloud harness, the rule -- future roles come with a scenario
- [x] `docs/cloud/digital-ocean/tests.md`, `tasks-and-linters.md`, `mkdocs.yml`, `docs/pipelines.md`, `docs/ansible/molecule.md` -- describe scenarios, tasks, job -- epic docs rule

**Acceptance Criteria:**
- Given the harness, when I run `task molecule-cloud:test`, then both scenarios pass converge, idempotence and verify; `task molecule-cloud:test:<role>` runs one.
- Given a role change that breaks an I/O-matrix expectation, when its scenario runs, then it fails.
- Given a push, when `pipeline.yml` runs, then `molecule-cloud` runs the matrix after linting and `generate-docs` waits for it.
- Given `task lint`, when it runs, then all linters pass.

## Implementation Notes

- The first design (privileged systemd container, `cgroupns_mode: host`, host `/sys/fs/cgroup` mounted rw, from the Code Map) rebooted the host three times: every reboot came about 1.5 min after a Molecule container with those settings started (container exit 255, `up 1 min`). A VS Code core dump `core.61281` (20:01) in the repo root is from the host's VS Code. Human decision: keep tests simple, never break the host, drop `swap`. Now plain unprivileged `ubuntu:26.04`, no systemd, a `systemctl` stub; `Dockerfile`, `swap` scenario and `swapon` stub removed. Planning docs (epics file, `epic-3-context.md`, architecture spine), `deferred-work.md` (untested `swap`) updated.
- systemd does not boot unprivileged with `--cgroupns=private` (`Failed to set RLIMIT_CORE: Operation not permitted`), so the stub is the only safe way to run the Alloy role unchanged. The scenarios do not prove Alloy starts; documented in `tests.md`.
- `prepare.yml` needed `gnupg` (`apt_repository`) and `sudo` (`become: true` tasks), both on the droplet (checked over SSH).
- ansible-lint lints `configs-cloud` (not `configs-homelab/tests`), and failed with `the role 'motd' was not found`; converge now uses relative role paths.
- Local runs need `DOCKER_CONFIG` pointing at an empty config: the devcontainer credential helper fails with `docker-credential-secretservice not found` since the host update. CI is not affected.
- `docs/pipelines.md` claimed `molecule` and `generate-docs` run in parallel; `pipeline.yml` already had `generate-docs` need `molecule`. Corrected while adding `molecule-cloud`.
- Verified: `task molecule-cloud:test:motd` and `:alloy` pass converge, idempotence (`changed=0`), verify; break checks (`alloy_stage: dev`, `20-updates` without the trailing `echo`) fail at the label and the one-update assertions, reverted; `task lint` all pass.

## Spec Change Log

## Review Triage Log

- medium (patch): the motd executables check uses `find -type f`, which skips the `50-landscape-sysinfo` symlink, so dropping the role's removal task stays green (verification-gap, blind). Verified by a break run. Fixed: `stat` + assert absent; break check (removal task deleted) fails at the new assertion.
- medium (patch): the `systemctl` stub accepts every call, so a dropped `notify` or handler goes unnoticed (blind, edge-case, verification-gap). Fixed without privileges: the stub logs its calls to `/var/log/systemctl-stub.log`, verify asserts exactly one `restart ... alloy` across converge and idempotence; break check (handler `state: started`) fails.
- low (patch): the alloy converge copied `default_user`, `alloy_fleet_extras` and the template path from `vars/main.yml`, so the test drifts when the droplet vars change (blind, edge-case). Fixed: `vars_files` loads `vars/main.yml`; `alloy_config_template` is a role parameter (beats `vars_files`) because the file builds it from the provision `playbook_dir`.
- low (patch): `tests.md` did not say the scenarios need internet (`apt.grafana.com` for `alloy`) (blind). Added.
- low (patch): `molecule-cloud` checked out the submodule it does not use (blind). Removed with a comment.
    - Correction after the first CI run: the patch broke both `molecule-cloud` jobs (`task: No Taskfile found at ".../.task/bmad/taskfile.yml"`). The root taskfile includes taskfiles from the `.task` submodule, so `submodules: true` is restored. Local runs could not show it, since the local checkout has every submodule.
- low (defer): the epics criterion says "Given a pull request" although `pipeline.yml` has no `pull_request` trigger (blind). Wording predates this story; recorded in `deferred-work.md`.
- low (rejected): removal of an existing `github.token` and binary capabilities is never exercised, since the container starts clean (edge-case, verification-gap). The intent's matrix covers the resulting state on a fresh host; the only droplet is already migrated (c3da9d4) and new droplets start clean; seeding needs Alloy installed before the role runs.
- low (rejected): `00-banner` and `10-os-line` are not executed, the banner file and debconf answer are not checked, no missing-stamp or non-numeric fixture (blind, edge-case). Outside the intent's matrix; the human asked for simple tests.
- low (rejected): container name `ubuntu-26.04` clashes with the homelab platform when scenarios run in parallel locally (edge-case). The taskfile runs them one by one and CI uses separate runners; both cloud scenarios use the default scenario name, so a per-scenario name needs more than a rename.
- low (rejected): floating `ubuntu:26.04` tag (blind); same as the homelab harness, pinning needs a digest-update process. No retries on network tasks, `test` stops at the first failing scenario (edge-case); same as the homelab harness, the network tasks are in the role.
- false: `landscape-common` in `prepare.yml` hides a non-idempotent debconf task on images without it (blind). The droplet ships it (`dpkg -l` over SSH: `ii landscape-common 26.02.2-0ubuntu1`), so `prepare` mirrors the real host.
- false: `'github' not in alloy_config` never shows the cloud template was rendered (blind). The `stage = "prod"` assertion (twice) only matches the cloud template; the fleet template has no `stage`. A harmless "github" mention fails loudly, which is acceptable.
- false: the spec is missing from the diff, `sprint-status.yaml` only at `in-progress` (blind). The spec is the claims file, kept out of the review diff on purpose; the story moves to review when this step finishes.
- false: "every cloud role has a scenario" contradicts the `swap` exception (blind). `epic-3-context.md`, the epics file, the architecture spine and `tests.md` all state the exception next to the rule.
- rejected (edits the spec): the Intent's Problem still lists `swap` (edge-case); the Always clause records the human decision.

## Verification

**Commands:**
- `task molecule-cloud:test` -- expected: both scenarios pass, idempotence `changed=0`.
- Break checks: temporarily set `alloy_stage: dev` in the alloy converge, and drop the final `echo` of `motd/files/20-updates`; run both scenarios -- expected: verify fails at the label and the one-update assertion; revert.
- `task lint` -- expected: all pass.
