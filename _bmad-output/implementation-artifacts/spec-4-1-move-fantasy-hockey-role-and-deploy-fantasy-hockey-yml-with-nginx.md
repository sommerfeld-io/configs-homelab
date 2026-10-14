---
title: 'Move fantasy-hockey role and deploy-fantasy-hockey.yml with nginx'
type: 'feature'
created: '2026-10-14'
status: 'done'
route: 'dispatch'
baseline_commit: '5a3a0494665d36076555472065951520380f2fac'
review_loop_iteration: 2
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The fantasy hockey app runs on pi4-0002 behind a home-router port forward, which is unstable and exposes the home network. The droplet from Epics 2–3 is provisioned but runs no app.

**Approach:** `git mv` the compose role to `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey` (vars renamed to `fantasy_hockey_`, vault secrets split out). Add `deploy-fantasy-hockey.yml`, which runs the stack as a dedicated `fantasy-hockey` user, with data on the volume. Add a Molecule scenario, then retire the Pi deployment with a cleanup play.

## Boundaries & Constraints

**Always:**

- Deploy dir and data live at `/mnt/prod_fantasy_hockey_data/fantasy-hockey` (`fantasy_hockey_path`). The playbook asserts that `/mnt/prod_fantasy_hockey_data` is a mount point before it writes anything.
- `fantasy-hockey.yml` is seeded only when absent and never touched afterwards.
- docker compose runs as `fantasy-hockey`. That user comes from the submodule `docker` role (`tasks_from: 50-user`), and its `.bashrc` from the `bash` role (`tasks_from: 10-bash-config`). The user has no SSH key; operators use `sudo -iu fantasy-hockey`.
- A second deploy run reports `changed=0`.
- Molecule containers are unprivileged, with no systemd and no host mounts. Pull-request CI never needs the vault password.
- Pi cleanup targets only pi4-0002. It fails before removing anything if a container runs there that is neither part of the fantasy-hockey project nor a fleet container (`cadvisor` from `grafana-cloud/exporters`).
- Decision (loop 2): fleet containers that the homelab roles put on every Pi (today `cadvisor`) are expected and do not block the cleanup; any other container still does.
- Decision: the Pi cleanup deletes `/opt/fantasy-hockey` without a backup. The Pi's data is not kept.
- Decision: `ps1` for `fantasy-hockey` is the `ubuntu_server` orange (`38;5;208`) prompt without `$(__git_ps1)`: `'${debian_chroot:+($debian_chroot)}\[\033[1;38;5;208m\]\u@\h:\[\033[1;34m\]\w\[\033[00m\] $ '`.
- Decision: keep the full spec (about 2,500 tokens) as one story; the Pi cleanup is not split off.

**Never:** HTTPS, a domain or Caddy; backups or alerts; migrating Pi data onto the droplet; a DigitalOcean firewall or user-data; adding the user in `provision.yml`; running the full `docker` role again in deploy (its `state: latest` install is not idempotent).

## I/O & Edge-Case Matrix

| Scenario                       | Input / State                                             | Expected Output / Behavior                                         | Error Handling                                          |
|--------------------------------|-----------------------------------------------------------|--------------------------------------------------------------------|---------------------------------------------------------|
| First deploy                   | Volume mounted, no data file                              | Files written, data seeded with UID 1000, stack up, both containers running | N/A                                                     |
| Re-deploy                      | Data file exists and was edited                           | Data file untouched, `changed=0`                                    | N/A                                                     |
| Config change                  | `docker-compose.yml`, nginx conf or `.env` differs         | File replaced, stack restarted                                      | N/A                                                     |
| Volume not mounted             | `/mnt/prod_fantasy_hockey_data` is not a mount point      | Nothing written                                                     | Assert fails, naming the missing mount                   |
| Pi cleanup with other containers | pi4-0002 runs a container outside the project and the fleet | Nothing removed                                                     | Assert fails, listing the other containers               |
| Pi cleanup rerun               | `/opt/fantasy-hockey` already gone                        | No-op, `changed=0`                                                  | N/A                                                     |

</frozen-after-approval>

## Code Map

- `configs-homelab/ansible/roles/raspi/fantasy-hockey/` -- the role to `git mv`: tasks, the static compose file (`${VAR}` values from `.env`), `files/nginx/default.conf`, `env.j2`, `fantasy-hockey.yml.j2` and a fully vault-encrypted `defaults/main.yml`.
- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- pattern for plays and relative include paths. It installs Docker, so the `docker` group exists before deploy runs. Don't change it.
- `configs-cloud/digital-ocean/ansible/vars/main.yml` -- `default_user: root` for provision. The deploy play must not load it: `vars_files` outrank play `vars`.
- `configs-cloud/digital-ocean/ansible/requirements.yml` -- add a pin for `community.docker` (5.4.0 is installed locally).
- `ansible-roles-collection/docker/tasks/50-user.yml` and `bash/tasks/10-bash-config.yml` -- reuse these. `user` creates home from skel; `10-bash-config` needs `ps1`.
- `configs-cloud/taskfile.yml` -- the `*do-token` precondition and the `digital-ocean:deploy` chain.
- `configs-cloud/digital-ocean/tests/molecule/{base,prepare,taskfile}.yml` and `motd/` -- the scenario pattern.
- `.github/workflows/pipeline.yml:155` -- the `molecule-cloud` matrix.
- `.folderslintrc` -- `roles/*/files` lacks a sub-folder rule, so `files/nginx` fails until the rule is added.
- `.ansible-lint.yml` -- playbooks that load a vault through `vars_files` must be excluded (issue #172). `deploy-fantasy-hockey.yml` loads its vault with an `include_vars` task instead, so it stays linted.
- `configs-homelab/ansible/playbooks/all.yml` -- imports `raspi.yml`, so every play in `raspi.yml` runs on each `task ansible:all` and `task ansible:raspi`.
- Path references: `.github/dependabot.yml:35`, `configs-homelab/ansible/taskfile.yml:105`, `configs-homelab/ansible/playbooks/raspi.yml:98-107`, `docs/pipelines.md:107-112`.
- `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2:237` -- scrapes `localhost:8080/metrics`. The compose file binds the app to `127.0.0.1:8080`, so the scrape works as is.

## Tasks & Acceptance

**Execution:**

- [x] `git mv` the role to `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey`, and `git mv` its `defaults/main.yml` to `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml`. Rename `raspi_fantasy_hockey_` to `fantasy_hockey_` and task names to `Fantasy Hockey  ----  …`. Split the tasks:
    - `tasks/user.yml` -- include `docker` `50-user` and `bash` `10-bash-config` (relative paths into `ansible-roles-collection`), passing `ps1: "{{ fantasy_hockey_ps1 }}"`.
    - `tasks/files.yml` -- directories, files, `.env` 0600, and the seed gated on `stat`.
    - `tasks/main.yml` -- assert that `fantasy_hockey_volume_mount` is in `ansible_facts.mounts` and that `fantasy_hockey_path` starts with `fantasy_hockey_volume_mount ~ '/'`. Then include `user.yml` and `files.yml`, and run compose up, restart on change and the asserts with `become_user: "{{ default_user }}"`.
- [x] Write new plain `defaults/main.yml` with `fantasy_hockey_volume_mount: /mnt/prod_fantasy_hockey_data`, `fantasy_hockey_path: "{{ fantasy_hockey_volume_mount }}/fantasy-hockey"`, season, deadline and `fantasy_hockey_ps1` (the decided prompt). This file is the only copy of the prompt. Update the README.
- [ ] HUMAN: run `task cloud:digital-ocean:vault:fantasy-hockey`, rename the keys, and keep only `session_secret`, `smtp_*` and `players`. The vault password is never available to the agent.
- [x] `configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml` -- add a play on hosts `fantasy-hockey` with become and play vars `ansible_pipelining: true` and `default_user: fantasy-hockey`, and without `vars_files`. Tasks: `include_vars` for `../vars/fantasy-hockey-vault.yml`, then `include_role` `../roles/fantasy-hockey`. Do not add it to `.ansible-lint.yml` `exclude_paths`; `task lint` must lint it.
- [x] `configs-cloud/digital-ocean/ansible/requirements.yml` -- pin `community.docker`, with a comment naming the role `fantasy-hockey` (it runs the docker modules).
- [x] `configs-cloud/taskfile.yml` -- add `digital-ocean:ansible:deploy-fantasy-hockey` and `digital-ocean:vault:fantasy-hockey`, and append the deploy to `digital-ocean:deploy`.
- [x] `configs-homelab/ansible/taskfile.yml` -- remove `vault:fantasy-hockey`. Add `raspi:fantasy-hockey-cleanup`, which runs `raspi.yml` with `--tags fantasy-hockey-cleanup` (same flags as `*ansible-cmd`). In `.github/dependabot.yml`, repoint the compose entry to the new `files` path.
- [x] `configs-homelab/ansible/playbooks/raspi.yml` -- replace the pi4-0002 play with a cleanup play tagged `[never, fantasy-hockey-cleanup]`, so `task ansible:raspi` and `task ansible:all` skip it. It lists containers and asserts that only `fantasy-hockey-*` and the fleet containers (a play var list, today `[cadvisor]`) run, then runs `docker_compose_v2 state: absent` and removes `/opt/fantasy-hockey`, both only when the folder exists. No backup.
- [x] `configs-cloud/digital-ocean/tests/molecule/fantasy-hockey/molecule/default/{molecule,converge,verify}.yml`:
    - Converge runs the role with `tasks_from: user`, then `tasks_from: files`. Test values (`default_user`, a plain `fantasy_hockey_path` that overrides the mount-derived default, fake secrets and players) go in `vars/test-vars.yml`, not `molecule.yml`. Converge sets no `ps1`.
    - Verify loads the role's `defaults/main.yml` with `include_vars` and asserts the PS1 line against `fantasy_hockey_ps1`. It also checks the user is in `docker`, owners and modes, `.env` 0600 with the test values, the seeded content, and the seed rule.
    - Add `test:fantasy-hockey` to the scenario taskfile and the `pipeline.yml` matrix.
- [x] Loop 2 patches: in `tasks/main.yml` compare `fantasy_hockey_path | ansible.builtin.normpath` in the path guard; in `deploy-fantasy-hockey.yml` load the vault from `"{{ playbook_dir }}/../vars/fantasy-hockey-vault.yml"`; in the Molecule `verify.yml` run the role's `main` entry inside `block`/`rescue` twice (an unmounted `fantasy_hockey_volume_mount`, and a mounted one such as `/etc/hostname` with a path outside it, plus a `..` path) with a fresh `default_user` and path, and assert each case was rescued and neither that user nor that folder exists.
- [x] `.folderslintrc` -- allow `configs-cloud/*/ansible/roles/*/files/**`.
- [x] `docs/cloud/digital-ocean/` -- add `deployment.md` (deploy, user, paths, seed rule, the Pi retirement with `task ansible:raspi:fantasy-hockey-cleanup`). Update `tasks-and-linters.md`, `tests.md`, `index.md` (the droplet node shows tags `prod` and `fantasy-hockey`), the `mkdocs.yml` nav and `docs/pipelines.md`. Check the earlier pages for drift.

**Acceptance Criteria:**

- Given a clean checkout, when `task lint` and `task cloud:molecule:test:fantasy-hockey` run, then both pass without a vault password.
- Given the role moved, when grepping for `roles/raspi/fantasy-hockey`, then only `_bmad-output` matches.
- Given a provisioned droplet, when the user runs `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` twice, then the second run reports `changed=0`, `http://<reserved-ip>` serves the app from outside the home network, `/metrics` returns 404, and `docker compose ps` run as `fantasy-hockey` lists both containers.
- Given the app runs, when querying Grafana Cloud for `job="fantasy-hockey"`, then `up=1` with `environment=digital-ocean` and `stage=prod`.
- Given the droplet is verified, when the user runs `task ansible:raspi:fantasy-hockey-cleanup`, then `/opt/fantasy-hockey` and both containers are gone; `task ansible:raspi` alone never runs the cleanup.

## Implementation Notes

- `deploy-fantasy-hockey.yml` does not load `vars/main.yml`: `vars_files` outrank play `vars`, so its `default_user: root` would beat the play's `default_user: fantasy-hockey`. The play needs nothing else from that file.
- The role asserts the mount from `ansible_facts.mounts` (role default `fantasy_hockey_volume_mount`) at the top of `tasks/main.yml`, before `user.yml` writes anything.
- Molecule test values live in `fantasy-hockey/molecule/default/vars/test-vars.yml`, loaded by converge and verify. Not in `molecule.yml` (Molecule expands `${...}` in the prompt), and under `vars/` so ansible-lint treats the file as vars, not as a playbook.
- ansible-lint's syntax check cannot decrypt a vault loaded through `vars_files`. `deploy-fantasy-hockey.yml` loads `fantasy-hockey-vault.yml` with an `include_vars` task, which the syntax check does not run, so the playbook is not in `exclude_paths` and is linted.
- `include_role` resolves a relative role name against the playbook folder, not the including role. `tasks/user.yml` therefore builds the paths from `role_path`, so they resolve the same from `deploy-fantasy-hockey.yml` and from the Molecule converge.

## Spec Change Log

- **Loop 1 (review of the first implementation).**
    - *Triggers:* (a) the Pi cleanup play sat untagged in `raspi.yml`, which `all.yml` imports, so any routine `task ansible:all` would delete the live Pi app before the droplet was verified, and the cleanup's container check would then fail every later run whenever any other container runs on pi4-0002 (high); (b) `deploy-fantasy-hockey.yml` was excluded from ansible-lint, and the Molecule converge hand-copied its role includes and its `ps1`, so playbook paths and prompt drift were never checked (medium).
    - *Amended:* the Tasks section (role `tasks/user.yml`; mount and path asserts in the role; prompt as the role default `fantasy_hockey_ps1`; vault loaded with `include_vars` so the playbook is linted; cleanup tagged `never` with its own task), the Code Map entries for `.ansible-lint.yml`, `vars/main.yml` and `all.yml`, and the cleanup acceptance criterion.
    - *Known-bad states avoided:* a routine run deleting the Pi app; a lint-excluded playbook; two copies of the prompt; a path override that escapes the volume check.
    - *Rework mode:* by the user's decision the first implementation was not reverted; it is still in the working tree, uncommitted. Bring it in line with the amended Tasks section in place: change what the amendment changes, keep the rest. All tasks are unchecked again, so check every one against the tree.
    - *KEEP:* the `git mv` moves (including the vault file rename with 100% similarity); `files.yml` content, owners, modes and the `stat`-gated seed with its comment; `ansible_pipelining`, and not loading `vars/main.yml` (`vars_files` outrank play `vars`); the test values in `vars/test-vars.yml` (Molecule expands `${...}`; under `vars/` so ansible-lint does not read it as a playbook); the verify assertions; the taskfile tasks, Dependabot, pipeline matrix and folderslint changes; the docs structure and content of `deployment.md`, `tasks-and-linters.md`, `tests.md`, `index.md`, `provisioning.md`, `pipelines.md` and `mkdocs.yml`.
- **Loop 2 (review of the reworked implementation).**
    - *Trigger:* intent gap: pi4-0002 runs `cadvisor` (exporters role on every `raspi` host), so the frozen "no other container" guard failed on every run (high). The human decided: fleet containers are expected.
    - *Amended:* frozen Boundaries (decision recorded by the human), the matrix row wording, the cleanup task (allow-list play var), and a patch task for the guards test, `normpath` and the `playbook_dir` vault path.
    - *Known-bad state avoided:* a cleanup that can never run.
    - *Rework mode:* again in place by the user's earlier decision; tasks are unchecked for re-verification.
    - *KEEP:* everything from loop 1 KEEP plus the loop 1 rework (`tasks/user.yml` with `role_path` includes, guards in `tasks/main.yml`, `fantasy_hockey_ps1` default read by verify through a `role_defaults` namespace, `include_vars` vault, the `never` tag and `raspi:fantasy-hockey-cleanup` task).

## Review Triage Log

Loop 1. Reviewers: blind-hunter (BH), edge-case-hunter (EC), verification-gap (VG).

| #  | Source      | Finding                                                                                  | Verdict     | Evidence                                                                                                                                         | Route    |
|----|-------------|------------------------------------------------------------------------------------------|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| 1  | BH          | Pi cleanup play runs on every `raspi.yml` / `all.yml` run                                | high        | `all.yml:9` imports `raspi.yml`; the play had no tag, so `task ansible:all` deletes `/opt/fantasy-hockey` before the droplet is verified         | bad_spec |
| 2  | VG, BH, BH  | Deploy playbook not linted; converge and `test-vars.yml` hand-copy its includes and `ps1` | medium      | `.ansible-lint.yml` excluded the playbook; converge repeated the three `include_role` calls; verify asserted the test copy of `ps1`             | bad_spec |
| 3  | EC, BH      | Volume assert does not check that `fantasy_hockey_path` lies under the mount              | medium      | The assert only looked at `/mnt/prod_fantasy_hockey_data`; a vault-defined `fantasy_hockey_path` (old key renamed) would outrank the role default | bad_spec (folded into the loop 1 amendment) |
| 4  | BH          | `index.md` droplet node shows only tag `prod`                                            | low         | `docs/cloud/digital-ocean/index.md:32` "tag prod"; OpenTofu sets `tags = ["fantasy-hockey"]` too                                                 | bad_spec (folded in) |
| 5  | BH          | `requirements.yml` comment names the playbook, not the role that runs the docker modules  | low         | The modules are in `roles/fantasy-hockey/tasks/main.yml`                                                                                          | bad_spec (folded in) |
| 6  | VG          | Pi cleanup play has no automated test                                                    | medium      | Filed by VG with evidence: `raspi.yml` is lint-excluded and no test touches it; Docker cannot run in the unprivileged containers                 | defer    |
| 7  | VG          | Compose start, restart on change and asserts only checked by hand                        | medium      | Filed by VG: converge runs `tasks_from: files` only; unprivileged containers cannot run Docker                                                    | defer    |
| 8  | BH          | Data dir 0755 and data file 0644 expose player emails to other local users                | low         | Pre-existing modes from the Pi role; on the droplet only system users exist besides root and `fantasy-hockey`                                     | defer    |
| 9  | EC, BH      | Deploy fails mid-role when the vault still has `raspi_` keys                              | low         | Fails loudly on the undefined variable at `env.j2`; a rerun after the HUMAN rename completes. Fail-loud is correct                               | reject   |
| 10 | EC          | Empty `fantasy-hockey` group: play exits 0 with "no hosts matched"                        | low         | Real, but Ansible warns, and the droplet carries the tag; fix adds a guard play                                                                  | reject   |
| 11 | EC, BH      | Mount path hard-codes `prod`                                                             | low         | Only one droplet exists (frozen: data at `/mnt/prod_fantasy_hockey_data/...`); no repo rule forbids it; deriving needs new parameters           | reject   |
| 12 | EC          | Failed run between file change and restart skips the restart on rerun                     | low         | Pre-existing pattern; `state: present` recreates on compose and `.env` changes anyway; handler rework adds complexity                            | reject   |
| 13 | EC, BH      | `State.Running` passes for a crash-looping app; no HTTP smoke test                        | low         | Pre-existing asserts; the reachability checks are manual acceptance checks; fix adds retry loops                                                 | reject   |
| 14 | EC          | `.env` values with `$`, quotes or newlines get interpolated                              | low         | Pre-existing; operator-controlled vault values                                                                                                   | reject   |
| 15 | EC          | Containers running while `/opt/fantasy-hockey` is gone are left                           | low         | The folder exists on pi4-0002 today; the cleanup runs once                                                                                       | reject   |
| 16 | EC          | Folder present but compose file missing makes compose down fail                          | low         | Fails loudly; not a reachable state on pi4-0002 today                                                                                            | reject   |
| 17 | EC          | An unrelated container named `fantasy-hockey-*` passes the guard                          | low         | No such container on the Pi; label filter adds complexity                                                                                        | reject   |
| 18 | EC (claim)  | Cleanup leaves containers when the folder is gone                                        | low         | Same as #15                                                                                                                                      | reject   |
| 19 | EC (claim)  | Vault not split, contradicts "secrets split out"                                         | false       | The split is the explicit open HUMAN task in the spec, not a code defect                                                                         | reject   |
| 20 | BH          | No data migration from the Pi                                                            | false       | Frozen decision: the Pi cleanup deletes the data without a backup; migration is out of scope                                                     | reject   |
| 21 | BH          | Double restart on config change                                                          | low         | Pre-existing; one extra restart on a config change, no user-visible harm                                                                         | reject   |
| 22 | BH          | Cleanup leaves images; name-based guard                                                  | low         | Disk space on the Pi only; guard covered by #17                                                                                                  | reject   |
| 23 | BH          | `deploy` asks for the vault password twice                                               | low         | Documented trade-off in the spec; a password file comes with the CI work in Epic 6                                                               | reject   |

Loop 2 (review of the reworked implementation).

| #  | Source        | Finding                                                                                   | Verdict     | Evidence                                                                                                                                              | Route      |
|----|---------------|-------------------------------------------------------------------------------------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|------------|
| 24 | EC, EC, BH    | Cleanup guard fails on every run: pi4-0002 runs `cadvisor` from the exporters role         | high        | `grafana-agents.yml:3` targets `raspi`; `grafana-cloud/exporters/files/docker-compose.yml:6` `container_name: cadvisor`; the guard rejects every non-`fantasy-hockey-` name | intent_gap |
| 25 | VG, BH        | Volume and path guards in `tasks/main.yml` run in no test                                 | medium      | Filed by VG: converge and verify use `tasks_from: user` and `files` only; the guards need no Docker                                                   | patch      |
| 26 | EC, BH        | Path guard compares strings; `..` escapes the volume                                      | low         | `startswith` on the raw string accepts `/mnt/prod_fantasy_hockey_data/../root`; fix is one `normpath` filter                                         | patch      |
| 27 | BH            | `include_vars` path relies on search-path fallback                                        | low         | `../vars/...` resolves via `playbooks/vars/../vars` miss, then the playbook folder; `playbook_dir` makes it explicit                                  | patch      |
| 28 | VG            | Deploy playbook `default_user` wiring not verified                                        | medium      | Filed by VG: the scenario sets `default_user` from `test-vars.yml`, never through the playbook                                                       | defer      |
| 29 | BH            | `docker_container_info` needs `python3-requests` on the droplet                           | maybe-false | Settle with `dpkg -s python3-requests` on the droplet (cloud-init usually depends on it); medium if missing                                           | defer      |
| 30 | BH, EC        | No assert on vault variables before writing                                               | low         | carried #9: fails loudly at `env.j2`; rerun after the HUMAN rename completes                                                                          | reject     |
| 31 | EC            | `.env` values with special characters                                                     | low         | carried #14                                                                                                                                           | reject     |
| 32 | EC            | Containers left when `/opt/fantasy-hockey` is missing; compose file missing               | low         | carried #15, #16                                                                                                                                      | reject     |
| 33 | BH            | No migration or backup of Pi data                                                         | false       | carried #20: frozen decision                                                                                                                          | reject     |
| 34 | BH            | Double restart; `State.Running` weak, no HTTP smoke test                                  | low         | carried #21, #13                                                                                                                                      | reject     |
| 35 | BH            | `deploy` asks for the vault password twice                                                | low         | carried #23                                                                                                                                           | reject     |
| 36 | BH            | Cleanup leaves images; lists running containers only                                      | low         | carried #22; the `-a` and scope questions fold into #24                                                                                               | reject     |
| 37 | EC            | Trailing slash in `fantasy_hockey_volume_mount` breaks both asserts                       | low         | Fails loudly; only an operator override can trigger it                                                                                                | reject     |
| 38 | EC            | Uninitialized submodule breaks the include                                                | low         | Same precondition as `provision.yml` since Epic 3; fails loudly                                                                                       | reject     |
| 39 | BH            | Cutover not documented: player notice, router port forward, HTTPS follow-up               | low         | HTTPS is out of scope by intent; `deployment.md` names the port-forward removal                                                                        | reject     |
| 40 | BH            | Verify checks modes, not file content; `src:` prefixes dropped                            | false       | Converge copies both files from the role's `files/` (Molecule passed), so the `src:` paths resolve; content is static                                 | reject     |
| 41 | EC (claim)    | Deploy cannot reach `changed=0` until the vault rename                                    | false       | carried #19: open HUMAN task                                                                                                                          | reject     |

Loop 3 (review after the loop 2 rework).

| #  | Source        | Finding                                                                                   | Verdict | Evidence                                                                                                                              | Route  |
|----|---------------|-------------------------------------------------------------------------------------------|---------|---------------------------------------------------------------------------------------------------------------------------------------|--------|
| 42 | VG            | Path guard's `~ '/'` (sibling prefix) is not tested                                       | medium  | Filed by VG: both path cases fail the guard with or without the `/`; dropping it would accept `/mnt/prod_fantasy_hockey_data_old/x`    | patch  |
| 43 | BH            | `raspi:fantasy-hockey-cleanup` description exceeds the yamllint line limit                 | low     | `configs-homelab/ansible/taskfile.yml:69` is 168 characters; `.yamllint.yml` `line-length` max 150 at level warning                    | patch  |
| 44 | BH            | A converge comment is not re-wrapped                                                       | low     | Edited line about 145 characters among lines wrapped near 80                                                                           | patch  |
| 45 | BH            | `fantasy_hockey_ps1` comment says "The only copy", but it is copied from `hosts.yml`         | low     | `defaults/main.yml:19`; the source is the `ubuntu_server` `ps1` in `configs-homelab/ansible/hosts.yml`                                 | patch  |
| 46 | BH            | `--diff` prints `.env` secrets and player emails                                          | low     | Pre-existing: the Pi role's template tasks had no `diff: false` either                                                                 | defer  |
| 47 | EC            | Player names with `:` or `#` make the seeded YAML invalid                                 | low     | Pre-existing template; operator-controlled vault values                                                                               | reject |
| 48 | EC            | `normpath` does not resolve symlinks below the mount                                      | low     | Needs a symlink planted on the volume by hand                                                                                         | reject |
| 49 | VG            | Compose part, `default_user` wiring and Pi cleanup untested                               | medium  | carried #6, #7, #28: already in `deferred-work.md`                                                                                    | defer  |
| 50 | BH, EC        | Vault keys not renamed; no vault-variable assert                                          | low     | carried #9, #19, #30                                                                                                                  | reject |
| 51 | BH            | No migration or backup of Pi data                                                         | false   | carried #20                                                                                                                           | reject |
| 52 | BH            | Mount path hard-codes `prod`                                                              | low     | carried #11                                                                                                                           | reject |
| 53 | BH, EC        | Empty group exits 0; submodule not initialised                                            | low     | carried #10, #38                                                                                                                      | reject |
| 54 | BH, EC        | Double restart; crash-loop `State.Running`; `.env` special characters                     | low     | carried #21, #13, #14                                                                                                                 | reject |
| 55 | BH, EC        | Cleanup leaves images; containers left when the folder is gone                            | low     | carried #22, #15                                                                                                                      | reject |
| 56 | BH            | New vault file missing from the yamllint and ansible-lint ignore lists                     | false   | `task lint` exits 0 with the file in place: yamllint reads the ciphertext as a plain scalar, and ansible-lint does not load it as content |reject |
| 57 | BH            | Plain HTTP on a public IP without a firewall is not called out                             | false   | Out of scope by intent: no HTTPS and no DigitalOcean firewall (frozen Never); `deployment.md` states it                                | reject |
| 58 | BH (re #56)   | Correction to #56: yamllint does warn on the vault file                                    | low     | `task lint` log: `fantasy-hockey-vault.yml` 1:1 `document-start` warning; `.yamllint.yml` ignores the other vault files, not `configs-cloud/*/ansible/vars/*-vault.yml`. The ansible-lint half of #56 stays false | patch  |
| 59 | BH (re #56)   | Correction to #56: ansible-lint also tries to decrypt the vault file                       | low     | `task lint` log: "Ignored exception from JinjaRule/VariableNamingRule ... fantasy-hockey-vault.yml ... Decryption failed"; the other vault files are in `.ansible-lint.yml` `exclude_paths` | patch  |

## Verification

**Commands:**

- `task lint` -- expected: all linters pass.
- `task cloud:molecule:test:fantasy-hockey` -- expected: converge, idempotence and verify pass.
- `git grep -n 'roles/raspi/fantasy-hockey' -- . ':(exclude)_bmad-output'` -- expected: no output.

**Manual checks (if no CLI):**

- The user runs the droplet deploy, the reachability and metrics checks, and then the Pi cleanup, in that order. Each step needs the vault password.
