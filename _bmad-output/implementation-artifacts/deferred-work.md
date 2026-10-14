- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`, `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Keep the exact OpenTofu pins in sync: the devcontainer feature `version`, the `lint-opentofu` image in `docker-compose.yml` and `required_version` in `configs-cloud/digital-ocean/opentofu/versions.tf` (plus the unpinned host install, see the Epic 2 retro action item 4).
  evidence: Only the compose image is bumped by Dependabot (there is no `devcontainers` ecosystem entry), and nothing bumps `required_version`; a devcontainer or host version other than 1.12.7 makes local `init`/`plan` fail on the version constraint, and no check catches it first. Raised again in the code review of Story 2.4.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`, `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Update `.github/copilot-instructions.md` (symlinked as `CLAUDE.md`) to mention `configs-cloud/`, the `task cloud:digital-ocean:*` tasks, the `opentofu` linter in the `task lint` list and that `task lint` runs `cloud:digital-ocean:opentofu:fmt` first.
  evidence: The Key Commands comment still lists the linters without `opentofu`; agent-instruction edits are out of scope for a build review fix.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-docs-skeleton-for-cloud-digital-ocean.md`
  summary: Drop the stale `export DIGITALOCEAN_TOKEN` line from existing `.bashrc` files via `bash-secrets.yml`, and make the write replace an existing export instead of appending a second line when the token is rotated (Epic 2 retro action item 3).
  evidence: The devcontainer half of this entry was fixed in `6f8671f`. `configs-homelab/ansible/tasks/bash-secrets.yml` still removes only `GITHUB_METRICS_EXPORTER_TOKEN` as obsolete, and its `lineinfile` has no `regexp`.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Add a token-free `tofu init -backend=false && tofu validate` check for `configs-cloud/digital-ocean/opentofu` to `task lint` and the CI lint matrix (Story 6.1).
  evidence: `lint-opentofu` (`docker-compose.yml`) runs only `fmt -check`; a wrong attribute reference or a breaking provider bump from the weekly `opentofu` Dependabot entry passes CI and fails only at a manual `plan`. Raised again in the code review of Story 2.4 and in the Story 2.5 review.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-5-reserved-ip-and-2-gb-volume-with-prevent-destroy.md`
  summary: Add a repeatable check that `prevent_destroy` on the volume and the reserved IP still refuses a destroy plan.
  evidence: Only a one-time manual `tofu plan -destroy` proved it; deleting a `lifecycle` block passes `fmt -check` and CI. Needs real state, so it belongs with the remote-state and CI work in Epic 6.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-5-reserved-ip-and-2-gb-volume-with-prevent-destroy.md`
  summary: Prove a droplet replacement with an already existing volume and reserved IP assignment (detach, re-attach, still mounted, IP re-assigned).
  evidence: Story 2.5 created the volume and the assignment in the same apply as the replacement; Story 4.3 is the planned drill.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-2-retro-item-4-bashrc-token-cleanup.md`
  summary: Add `no_log: true` to the secret-carrying tasks in `bash-secrets.yml` and to the `include_tasks` loop in `desktop.yml`.
  evidence: The token travels through `line`/`item`, which Ansible prints in task output and diffs; this predates the change.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-2-retro-item-4-bashrc-token-cleanup.md`
  summary: Add a Molecule scenario that seeds an old `.bashrc` export and asserts a rotated secret leaves one line and `DIGITALOCEAN_TOKEN` is gone.
  evidence: The behavior was verified only by a manual scratch run; no automated test covers `bash-secrets.yml`.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-1-dynamic-inventory-and-base-provision-yml.md`
  summary: Confirm the Docker apt repository supports the Ubuntu 26.04 codename when `provision` first runs on the droplet.
  evidence: The `docker` role uses `distribution_release` for the repo suite; unverified (maybe-false, medium). The first real provision run settles it.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-1-dynamic-inventory-and-base-provision-yml.md`
  summary: Add an automated check for the dynamic inventory groups, the droplet `tags` merge and the `changed=0` second run.
  evidence: Only static linters reach `configs-cloud`; a wrong `do_tags` key silently leaves the `ubuntu` or `fantasy-hockey` group empty. Needs a token or fixture, fits Story 6.1.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-2-swap-and-alloy-on-the-droplet-with-environment-and-stage-labels.md`
  summary: Add an automated check that renders the cloud Alloy template and the inventory stage/environment values, and asserts swap and the active config on the droplet.
  evidence: Only static validation covers the new roles; dropping `external_labels` or the `copy` task would keep every check green. Needs a Molecule or InSpec scenario for cloud nodes or a real droplet.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-2-swap-and-alloy-on-the-droplet-with-environment-and-stage-labels.md`
  summary: Bring `provision.yml` back under ansible-lint once vault-encrypted vars no longer block it.
  evidence: The playbook is in `exclude_paths` of `.ansible-lint.yml` because lint cannot decrypt `grafana-vault.yml`; same cause as the fleet playbooks tracked in issue #172.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-4-droplet-motd-with-banner-live-os-line-and-update-info.md`
  summary: Add an automated check that runs the MOTD scripts against stamp fixtures (0, 1, N updates) and asserts only the role's scripts and 98-reboot-required stay executable, idempotently.
  evidence: Nothing in the repo runs the motd role or its scripts; a changed grep pattern or a dropped exclude would keep every check green. Cloud roles have no Molecule/InSpec harness yet.

## Deferred from: code review of spec-3-3 and spec-3-4 (2026-10-13)

- No automated check runs the MOTD scripts against stamp fixtures or asserts exec bits and idempotence (same as the build-review entry above; needs a cloud-role Molecule/InSpec harness).
- MOTD layout and second-run idempotence not yet observed on the droplet (maybe-false, medium if broken): settled by running `task cloud:digital-ocean:ansible:provision` twice and `ssh root@<ip> 'run-parts --lsbsysinit /etc/update-motd.d | cat -A'`.

## Deferred from: build split of epic-3 retro items 9, 10 and 16 (2026-10-13)

- source_spec: none
  summary: Fix the Epic 3 docs drift in tasks-and-linters.md, droplet.md and provisioning.md (epic-3 retro item 9).
  evidence: The concrete drift is listed in finding 4 of `epic-3-retro-2026-10-13.md` (tree without roles/, provision row without MOTD, folderslint row, ansible-lint exclusion, droplet.md Tags row, provisioning.md role order and stray blank line); the collections sentence in provisioning.md was already updated by item 10. Split from a combined build of retro items 9, 10 and 16; independently shippable, scheduled right after item 10.

- source_spec: none
  summary: Add a lychee retry or accept rule for 429 and 5xx in the markdown link check (epic-3 retro item 16).
  evidence: Finding 17 of `epic-3-retro-2026-10-13.md`: the pre-commit link check failed on transient GitHub 502/503 and a docs.ansible.com 429, forcing commit retries. Split from a combined build of retro items 9, 10 and 16; independently shippable, scheduled after item 9.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-10-pin-provisioning-collections.md`
  summary: Decide who bumps the Ansible Galaxy pins in `configs-cloud/digital-ocean/ansible/requirements.yml` and how (Renovate `ansible-galaxy` manager or a manual check per epic).
  evidence: Dependabot has no Galaxy ecosystem and the repo has no Renovate config, so `community.digitalocean 1.27.0` and `community.general 13.5.0` never get update PRs.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-10-pin-provisioning-collections.md`
  summary: Add a check that `provision.yml` resolves only against the collections installed from `requirements.yml`, so a new role using an unpinned collection (e.g. `community.docker`, `community.crypto`) fails loudly.
  evidence: The pin list was built by hand from a grep; the devcontainer already has `community.docker` and `ansible.posix` installed, so an unpinned use would silently work. Fits the cloud test-harness story (epic-3 retro item 15).

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-items-9-11-16-deploy-wait-docs-drift-link-retries.md`
  summary: Wait for the first-boot apt lock (apt-daily, unattended-upgrades) before the Docker role's apt tasks on a new droplet.
  evidence: maybe-false, medium if true. The wait play covers cloud-init only, and the apt module waits 60 s (default `lock_timeout`). Settled by the Story 4.3 replacement drill: watch for "Could not get lock" on a fresh droplet.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-items-9-11-16-deploy-wait-docs-drift-link-retries.md`
  summary: Move the wait play into a vault-free playbook (imported by `provision.yml`) so ansible-lint and `--syntax-check` can cover it in CI.
  evidence: `provision.yml` is in `exclude_paths` and its syntax check needs the vault password, so the new play (including the `hostvars` assert) was only checked by hand. Fits the cloud test-harness story (epic-3 retro item 15).

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-12-reconcile-idempotence-statement.md`
  summary: When epic-3 retro item 8 (stop fleet-only side effects) is built, remove the four-Alloy-task exception from `epic-3-context.md`, the Story 3.1 criterion in the epics file and `SPEC.md` CAP-2, and the matching sentence in `docs/cloud/digital-ocean/provisioning.md`.
  evidence: All four now say the exception lasts "until" item 8 lands, but item 8's action text in `sprint-status.yaml` does not mention restoring the plain "a second run changes nothing" statement, so it would go stale.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-12-reconcile-idempotence-statement.md`
  summary: Add `changed_when: false` to the read-only `docker version` and `docker compose version` tasks in `ansible-roles-collection/docker/tasks/ubuntu/40-info.yml`, then drop the Docker exception from `epic-3-context.md`, the Story 3.1 criterion, `SPEC.md` CAP-2 and `docs/cloud/digital-ocean/provisioning.md`.
  evidence: The second provision run on 2026-10-13 (epic-3 retro item 13) ended `changed=6`: the four expected Alloy tasks plus `Docker  ----  Setup  ----  Verify Docker installation` and `Verify Docker Compose installation`, both plain `command` tasks without `changed_when`. The fix belongs to the submodule repo (AD-8).

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-8-alloy-config-template-and-fleet-extras.md`
  summary: Add a Molecule scenario for the fleet `grafana-cloud/alloy` role with its apartment defaults (token file, capabilities and override capability lines present, one restart on a config change, none on a second converge).
  evidence: No test runs this role (`configs-homelab/tests/molecule` has only `common` and `omarchy`); Story 3.5 covers only the `alloy_fleet_extras: false` branch with the cloud template. A dropped `notify` or a mis-rendered `{% if %}` in the override would reach every apartment node unnoticed. Needs a systemd container and Grafana APT access.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-5-molecule-tests-for-the-cloud-ansible-roles.md`
  summary: The cloud `swap` role has no automated test; only a second provision run on the droplet checks it.
  evidence: Story 3.5 dropped the `swap` scenario by human decision on 2026-10-13. `swapon` needs a privileged container, and every run of a privileged systemd test container hung up the host's desktop session on `/dev/tty1` (root cause from Grafana Cloud logs, see the addendum in `epic-3-retro-2026-10-13.md`). A test would need a safe way to run `mkswap`/`swapon` (e.g. a disposable VM) without touching the host.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-5-molecule-tests-for-the-cloud-ansible-roles.md`
  summary: The Story 3.5 criterion in `epics-fantasy-hockey-digitalocean.md` still says "Given a pull request / When `pipeline.yml` runs", but `pipeline.yml` has no `pull_request` trigger; reword it to a push.
  evidence: `docs/pipelines.md` states `pipeline.yml` has no `pull_request` trigger and only runs on `push` (branches except `dependabot/**`) and the Tuesday schedule. The wording predates Story 3.5 (blind review finding).

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Add a test, or at least a `--check` dry run, for the pi4-0002 fantasy hockey cleanup play and its container guard.
  evidence: `raspi.yml` is excluded from ansible-lint and no test touches the play; Docker cannot run in the unprivileged Molecule containers. The play deletes data without a backup and runs for the first time on the real Pi.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Automate the check of the fantasy-hockey role's compose part (start, restart on a config change, running asserts).
  evidence: The Molecule scenario runs only the file tasks because unprivileged containers cannot run Docker; a broken register name or restart condition is only found on the droplet.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Tighten the modes of the fantasy hockey data folder and data file (0750/0640) so player emails are not readable by other local users.
  evidence: The data folder is 0755 and the seeded file 0644, carried over from the Pi role; the file lists every player's email. The app rewrites the file by atomic rename, so the file mode also depends on the app's umask.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Verify that `deploy-fantasy-hockey.yml` resolves `default_user` to `fantasy-hockey` (not `root` from `vars/main.yml`), for example with a vault-free play variant or an inventory fixture.
  evidence: The Molecule scenario sets `default_user` in `test-vars.yml` and never runs the playbook; adding `vars_files: [../vars/main.yml]` would make the stack run as root with CI green.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Confirm `python3-requests` is on the droplet (needed by `community.docker.docker_container_info`), or install it in `provision.yml`.
  evidence: Unverified (maybe-false, medium if missing). Settle with `dpkg -s python3-requests` on the droplet; cloud-init usually depends on it.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Set `diff: false` (or `no_log`) on the fantasy-hockey `.env` and data-file template tasks so `--diff` runs do not print secrets and player emails.
  evidence: The template tasks in `roles/fantasy-hockey/tasks/files.yml` print the full rendered content with `--diff`; carried over unchanged from the Pi role.
