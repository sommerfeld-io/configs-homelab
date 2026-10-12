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
