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
  summary: Add a `terraform` Dependabot ecosystem for `cloud-configs/digital-ocean/opentofu` once Story 2.4 commits the provider and `.terraform.lock.hcl`.
  evidence: No provider exists yet in Story 2.2, so the entry would have nothing to update; Story 2.4 pins the provider.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`
  summary: Update `.github/copilot-instructions.md` (symlinked as `CLAUDE.md`) to mention `cloud-configs/`, the `task cloud:digital-ocean:*` tasks and the `opentofu` linter in the `task lint` list.
  evidence: The Key Commands comment still lists the linters without `opentofu`; agent-instruction edits are out of scope for a build review fix.
