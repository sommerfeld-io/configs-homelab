---
title: 'Devcontainer tools and DIGITALOCEAN_TOKEN delivery'
type: 'feature'
created: '2026-10-12'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The devcontainer has neither `doctl` nor OpenTofu (`tofu`), and `DIGITALOCEAN_TOKEN` is exported on the workstation (`desktop.yml` already writes it to `.bashrc` from `vault.yml`) but is not passed into the devcontainer. Operators cannot run any DigitalOcean step locally, and the token scopes and manual steps are undocumented.

**Approach:** Install pinned `doctl` and `tofu` through devcontainer features, forward `DIGITALOCEAN_TOKEN` via `containerEnv` like `SONARCLOUD_TOKEN`, and document token scopes and manual steps in a first `docs/cloud/digital-ocean` page linked from the MkDocs nav.

</frozen-after-approval>

## Implementation Notes

- Pin per AD-7: `tofu` 1.12.7 (1.12.x line), `doctl` 1.183.0. Installed in `.devcontainer/Dockerfile` (build args, checksum-verified release downloads, `USER root` then back to `vscode`). Initially done via devcontainer features; switched to the Dockerfile at the user's request. `DIGITALOCEAN_TOKEN` stays in `devcontainer.json`.
- `ansible/playbooks/desktop.yml` already exports `DIGITALOCEAN_TOKEN` (commit afb0751); no change there. The vault value cannot be verified without the vault password.
- Docs page: `docs/cloud/digital-ocean/api-token.md` plus a "Cloud - Digital Ocean" nav item in `mkdocs.yml`; Story 2.3 extends the skeleton.
- Token scopes: droplet, ssh_key, volume, reserved IP, project (firewall or domain only if needed).
- Files changed: `.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, `docs/cloud/digital-ocean/api-token.md`, `mkdocs.yml`, `.folderslintrc` (allow `docs/cloud/**`, required by folderslint).
- Verified: the Dockerfile builds and `doctl version` / `tofu version` report 1.183.0 / 1.12.7. Not verified: the vault entry (needs the vault password).

## Review Triage Log

- medium (patched): doc used scope `volume`; DO scope is `block_storage` plus `actions` -- fixed in the scope table.
- medium (patched): doc did not say the vault entry must exist before the playbook runs -- added.
- low (patched): no hint for an empty `DIGITALOCEAN_TOKEN` in the devcontainer -- added a troubleshooting note.
- low (rejected): token plaintext in `.bashrc`, rotation/removal docs -- same accepted pattern as `SONARCLOUD_TOKEN`; fix would exceed the story.
- low (rejected): InSpec/Molecule coverage and secret scanning -- outside Story 2.1 scope; covered by later stories if wanted.
- false: submodule `m` status -- not part of this change; the commit stages explicit paths only.
