- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-manual-bootstrap-disposition-tags.md`
  summary: The manual-bootstrap checklist (SSH exchange, sudoers workaround, GitHub key setup, Docker login) is duplicated verbatim between `docs/nodes/raspi/index.md` and `docs/nodes/ubuntu-workstations/index.md` with no shared source or cross-reference.
  evidence: Pre-existing structural duplication, not introduced by this change — flagged by blind-hunter review during Story 1.1. If issue #160 closes or a disposition changes, both copies need synchronized manual edits with nothing linking them to make that easy to catch.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-manual-bootstrap-disposition-tags.md`
  summary: The `ansible-roles-collection` submodule pointer is left in a dirty/uncommitted state (`ea3ab018f00e270720de6ae3ec03ba0cb1644de0-dirty`), unrelated to this docs change.
  evidence: Pre-existing since before this session started (present at the very first `git status` check) — flagged by blind-hunter review during Story 1.1. Would break `git submodule update` for anyone else if committed as-is.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`
  summary: The OpenTofu pin exists twice (devcontainer feature `version` and the `lint-opentofu` image in `docker-compose.yml`) and only the compose one is bumped by Dependabot; add a `devcontainers` Dependabot ecosystem or another way to keep them in sync.
  evidence: `.github/dependabot.yml` has `docker-compose` for `/` but no `devcontainers` entry, so a compose bump leaves the devcontainer behind.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`
  summary: Update `.github/copilot-instructions.md` (symlinked as `CLAUDE.md`) to mention `cloud-configs/`, the `task cloud:digital-ocean:*` tasks and the `opentofu` linter in the `task lint` list.
  evidence: The Key Commands comment still lists the linters without `opentofu`; agent-instruction edits are out of scope for a build review fix.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-docs-skeleton-for-cloud-digital-ocean.md`
  summary: Map the devcontainer `DIGITALOCEAN_ACCESS_TOKEN` from host `${localEnv:DIGITALOCEAN_ACCESS_TOKEN}` (and drop the stale `export DIGITALOCEAN_TOKEN` line from existing `.bashrc` files via `bash-secrets.yml`).
  evidence: Since `a12d7ff`, `desktop.yml:25` exports only `DIGITALOCEAN_ACCESS_TOKEN`, but `.devcontainer/devcontainer.json:47` reads host `DIGITALOCEAN_TOKEN`; a freshly provisioned workstation gets an empty token in the devcontainer. Existing hosts still work only because their `.bashrc` keeps the old export line.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-docs-skeleton-for-cloud-digital-ocean.md`
  summary: Update `epics-fantasy-hockey-digitalocean.md` (Story 2.4 AC and related text) to the `DIGITALOCEAN_ACCESS_TOKEN` shell variable name.
  evidence: Story 2.4 AC still says "Given `DIGITALOCEAN_TOKEN` is set"; the implementer of 2.4 would read the stale name. Editing planning artifacts also invalidates the cached epic-2 context.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Add a token-free `tofu init -backend=false && tofu validate` check for `cloud-configs/digital-ocean/opentofu` to `task lint` and the CI lint matrix (Story 6.1).
  evidence: `lint-opentofu` (`docker-compose.yml:76`) runs only `fmt -check`; a wrong attribute reference or a breaking Dependabot provider bump passes CI and fails only at a manual `plan`.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Keep the three exact OpenTofu pins in sync: devcontainer feature, `lint-opentofu` image and `required_version` in `cloud-configs/digital-ocean/opentofu/versions.tf`.
  evidence: Story 2.4 added `required_version = "1.12.7"`; a devcontainer bump to another version without editing `versions.tf` makes local `init`/`plan` fail on the version constraint, and no check catches it first.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Agent instructions (`.github/copilot-instructions.md` / `CLAUDE.md`) should mention `cloud-configs/`, the `task cloud:digital-ocean:*` tasks, the `opentofu` linter and that `task lint` now runs `opentofu:fmt` first.
  evidence: Agent-context file edits are out of scope for a build review fix; the Key Commands list is still unchanged.

## Deferred from: code review of spec-2-4-opentofu-droplet-ssh-keys-tag-and-project (2026-10-12)

- No token-free `tofu init -backend=false && tofu validate` in `task lint` or the CI lint matrix, while the new `opentofu` Dependabot entry opens weekly provider bumps that can merge green; same item as the spec-2-4 validate entry above (Story 6.1).
- `required_version = "1.12.7"` is a third exact OpenTofu pin next to the devcontainer feature and the `lint-opentofu` image, with nothing keeping them in sync; same item as the spec-2-4 pin entry above.
