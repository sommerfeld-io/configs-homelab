---
title: 'Dynamic inventory and base provision.yml'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_commit: '18507cb3c8437ef82148d8a5c0bf8836f181e609'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The droplet `prod-fantasy-hockey` exists but has no software; Ansible has no way to find it without a hand-edited inventory (CAP-2, Story 3.1).

**Approach:** Add a `community.digitalocean` dynamic inventory under `configs-cloud/digital-ocean/ansible` that selects droplets by tag and composes the generic group `ubuntu` (all Ubuntu droplets) and `fantasy-hockey` (from a new droplet tag), plus a `provision.yml` for group `ubuntu` that runs as `root` (default user) and installs Docker and the root bash prompt by reusing roles from `configs-homelab/ansible/roles` via relative paths. Add the tag `fantasy-hockey` to the droplet in OpenTofu, a go-task entry point, and document it under `docs/cloud/digital-ocean`.

## Boundaries & Constraints

**Always:** Token passed explicitly as the plugin's `oauth_token` from `lookup('env', 'DIGITALOCEAN_ACCESS_TOKEN')`; `tags` in the plugin `attributes`. No static or committed inventory of hosts. Roles reused through relative `include_role` paths like `server.yml` does, never `roles_path`. Pin the `community.digitalocean` collection version (AD-7) in a committed requirements file. The task stops early with a message when `DIGITALOCEAN_ACCESS_TOKEN` is unset (same precondition as the OpenTofu tasks). `default_user` is `root`; only the root prompt is configured, using the root prompt of the local ubuntu machines (`ps1_root`), not yellow. `provision.yml` targets the generic group `ubuntu`, never `fantasy-hockey`. Droplet tags come from the map: `stage` plus an optional per-entry `tags` list; adding the tag is an in-place update, never a replacement. Planning docs that name the yellow prompt are corrected in the same change. A second run reports `changed=0`. Docs updated in the same change.

**Never:** No change to files under `configs-homelab/` or the submodule. No `tofu apply` without the user's confirmation in chat (plan only). No Alloy, swap or MOTD (Stories 3.2, 3.4). No `deploy-services.yml` or app deployment (Epic 4). No DO firewall, user-data or CI workflow. No vault file used for the token.

## I/O & Edge-Case Matrix

| Scenario              | Input / State                        | Expected Output / Behavior                                  | Error Handling                                  |
|-----------------------|--------------------------------------|-------------------------------------------------------------|-------------------------------------------------|
| Inventory listing     | Token set, droplet tagged `prod`     | `ansible-inventory --list` shows the droplet in `ubuntu` and `fantasy-hockey` | N/A                              |
| Token missing         | `DIGITALOCEAN_ACCESS_TOKEN` unset    | Task stops before Ansible runs                              | Message pointing to `api-token.md`              |
| First provision       | Fresh droplet                        | Docker and prompt installed                                 | N/A                                             |
| Second provision      | Already provisioned                  | `changed=0`                                                 | N/A                                             |
| Tag added             | `fantasy-hockey` added to the map | Plan: droplet updated in place | N/A |
| Droplet replaced      | New droplet, same tag                | Found again without editing anything                        | Host key change: `ssh-keygen -R` documented     |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/` -- empty (`.gitkeep`); gets `inventory/digitalocean.yml` (plugin config), `playbooks/provision.yml`, `requirements.yml` (pinned collection), vars file for `ps1`/`ps1_root`/`default_user`. Remove `.gitkeep`.
- `configs-cloud/taskfile.yml` -- tasks `digital-ocean:*` with token precondition `*do-token`; add `digital-ocean:provision` (and `digital-ocean:inventory` for listing) running `ansible-playbook`/`ansible-inventory` with `-i digital-ocean/ansible/inventory`.
- `configs-homelab/ansible/playbooks/server.yml` -- pattern to copy: `include_role` with `../roles/ansible-roles-collection/{bash,docker}` (`docker` with `tasks_from: main`), `become: true`, `gather_facts: true`. Do not edit.
- `configs-homelab/ansible/roles/ansible-roles-collection/bash/tasks/10-bash-config.yml` -- writes `/home/{{ default_user }}/.bashrc` and would fail for `root`, so do not run it. Include `bash` with `tasks_from: 11-bash-config-root` only (needs `ps1_root`, writes `/root/.bashrc`).
- `.../docker/tasks/50-user.yml` -- `user` module with `name: {{ default_user }}`, `groups: docker`; works for `root`.
- `.../docker/tasks/ubuntu/20-apt-repository.yml` -- uses `ansible_facts['distribution_release']`; Docker's repo must support the Ubuntu 26.04 codename, check at run time.
- `configs-homelab/ansible/hosts.yml` -- `ubuntu_desktop` `ps1_root` (`1;38;5;213` for `\u@\h`) is the root prompt of the local ubuntu machines (same value on `ubuntu_server`); copy that string verbatim into the cloud vars as `ps1_root`. Do not edit the file.
- `configs-cloud/digital-ocean/opentofu/droplets.tf` -- `tags = [each.value.stage]` (line ~66) and the options comment block; add an optional `tags` list option per map entry (extra tags, e.g. `fantasy-hockey`), merged with `stage`, keep the map documented. Inventory selects by tag `prod` (stage); groups: `ubuntu` via `do_image.distribution`, `fantasy-hockey` via `do_tags`.
- `.ansible-lint.yml` -- `profile: basic`, `configs-cloud` already linted; keep new YAML lint-clean.
- `.folderslintrc` -- `configs-cloud/*/ansible/**` already allowed. `.ls-lint.yml` -- kebab-case filenames.
- `docs/cloud/digital-ocean/{index,droplet,api-token,tasks-and-linters}.md` (tag lists, map option, `tags = [...]` mention in `api-token.md`), `mkdocs.yml` (nav) -- add a page `provisioning.md` (dynamic inventory, groups, task, host key note), update the layout block, task table and "configured later" sentence in `index.md`.
- Host addressing: the plugin returns the droplet's own public IPv4 (not the reserved IP); use that default. A replaced droplet gets a new host key.
- Planning docs naming the yellow prompt: `_bmad-output/planning-artifacts/epics-fantasy-hockey-digitalocean.md` (3.1 AC), `_bmad-output/specs/spec-fantasy-hockey-digitalocean/{SPEC.md,epics.md,platform-decisions.md,stories.yaml}`, `epic-3-context.md`; Story 3.1 text in `stories.yaml`/epics also mentions group wording.
- `community.digitalocean` is not installed in the devcontainer (`ansible-galaxy collection list`); the task installs it from `requirements.yml` before running.

## Tasks & Acceptance

**Execution:**
- [x] `configs-cloud/digital-ocean/ansible/requirements.yml` -- pin `community.digitalocean` -- AD-7
- [x] `configs-cloud/digital-ocean/ansible/inventory/digitalocean.yml` -- plugin config: tag filter, `oauth_token` env lookup, `attributes`, groups `ubuntu`, `fantasy-hockey` -- tag-based discovery
- [x] `configs-cloud/digital-ocean/opentofu/droplets.tf` -- optional `tags` per entry, `fantasy-hockey` on the droplet; `tofu plan` shows `1 to change`, no replacement -- group label
- [x] `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` and vars -- `hosts: ubuntu`, `default_user: root`, `docker` then `bash` (`tasks_from: 11-bash-config-root`) via relative paths, non-yellow `ps1_root` -- base provisioning
- [x] Planning docs listed in the Code Map -- replace "yellow prompt" with the root prompt of the local ubuntu machines; update `epic-3-context.md` -- keep planning docs consistent
- [x] `configs-cloud/taskfile.yml` -- `digital-ocean:provision` and `digital-ocean:inventory` with token precondition and collection install -- one entry point
- [x] `docs/cloud/digital-ocean/provisioning.md`, `index.md`, `tasks-and-linters.md`, `mkdocs.yml` -- document inventory, groups, task, replacement host key -- epic docs rule

**Acceptance Criteria:**
- Given the token is set, when I run the inventory task, then the droplet appears in `ubuntu` and `fantasy-hockey`.
- Given the token is set, when I run the provision task, then Docker and the root prompt are installed using roles from `configs-homelab/ansible/roles`.
- Given a second run, when it finishes, then `changed=0`.
- Given `task lint`, when it runs, then all linters pass.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- medium (patch): no `ansible_user`, so SSH uses the local login name instead of `root` (edge-case, blind). Fixed: inventory `compose` sets `ansible_user` to `root`; `ansible-inventory --host` shows it.
- medium (patch): first connection to a new droplet prompts for the host key and hangs an unattended run (edge-case, blind). Fixed: `compose` sets `StrictHostKeyChecking=accept-new`; changed keys are still refused; documented.
- low (patch): new table rows in `tasks-and-linters.md`, `droplet.md`, `api-token.md` not padded to column width (edge-case, blind, verification-gap). Fixed: tables re-padded; `api-token.md` row no longer quotes `concat(...)`.
- medium (defer): Docker apt repo may not support the Ubuntu 26.04 codename (edge-case, maybe-false). Settled by the first real `provision` run.
- medium (defer): no automated check evaluates the inventory filter, groups or `tags` merge, and the `changed=0` claim is manual only (verification-gap, blind). Needs a token or fixture; Story 6.1.
- false: `include_role` relative path resolves wrongly (blind, edge-case). A test play with the same path ran the `bash` role tasks from `configs-cloud`; they resolved.
- false: `epic-3-context.md` not updated (edge-case). The file was updated in the same change (shown in the prompt text); the hunk is outside the reviewed diff.
- false: no ansible-lint coverage of the new folder / ansible missing in the devcontainer (blind). `lint-ansible` runs `ansible-lint configs-homelab/ansible configs-cloud`; ansible ran here.
- false: prompt colour change unexplained (blind). It is the user's decision for this story, recorded in the frozen intent.
- low (rejected): hyphenated group name warning (blind). Name is fixed by the epic and spec; Ansible only warns.
- low (rejected): `prod` filter hardcoded, so a future `test` stage is skipped (blind). Intended: spec selects by stage tag; more stages mean editing the filter then.
- low (rejected): missing null guards on `do_image`, `do_tags`, empty token, empty group, `wait_for_connection`, `distinct` tags, `try` swallowing typos (edge-case, blind). Unlikely paths; fixes add guards or branches.
- low (rejected): `ps1_root` copy may drift from `hosts.yml`, `root` added to `docker` group is a no-op, collection reinstalled on each call, no `--limit` passthrough (blind, verification-gap). Cosmetic or harmless.
- medium (patch, found late): no explicit `ansible_host` (edge-case, blind), wrongly rejected as low. The plugin does not set it, so SSH tried to resolve `prod-fantasy-hockey` and the first real run failed. Fixed: `compose` sets `ansible_host` to the droplet's public IPv4.

## Verification

**Commands:**
- `ansible-galaxy collection install -r configs-cloud/digital-ocean/ansible/requirements.yml` -- expected: collection installed at the pinned version.
- `task cloud:digital-ocean:inventory` -- expected: droplet in both groups.
- `ansible-playbook --syntax-check -i configs-cloud/digital-ocean/ansible/inventory configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- expected: success.
- `task lint` -- expected: all pass.

**Manual checks (if no CLI):**
- User runs `task cloud:digital-ocean:provision` twice (agent SSH is blocked): first run installs, second reports `changed=0`; `docker --version` and the root prompt on the droplet. The `tags` change is applied only after the user confirms in chat.
- `task cloud:digital-ocean:plan` -- expected: only the droplet tags update in place.
