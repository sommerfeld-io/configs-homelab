---
title: 'cloud-configs scaffold with taskfile and linters'
type: 'feature'
created: '2026-10-12'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The `cloud-configs` bounded context (AD-10) does not exist yet. Stories 2.4 and 2.5 need `cloud-configs/digital-ocean/{opentofu,ansible}`, `task cloud:digital-ocean:*` entry points, and linter coverage so the new code is checked like the rest of the repo (CAP-6).

**Approach:** Create the two folders, add `cloud-configs/taskfile.yml` included in the root taskfile with prefix `cloud` (tasks `digital-ocean:*` that wrap `tofu`), extend folderslint, ls-lint and ansible-lint to cover the folder, add a pinned OpenTofu linter as a new `lint-opentofu` compose service run by `task lint` and the CI lint matrix, and document the tasks and linters under `docs/cloud/digital-ocean`.

</frozen-after-approval>

## Implementation Notes

- OpenTofu linter: `tofu fmt -check -diff -recursive cloud-configs` in `ghcr.io/opentofu/opentofu:1.12.7` (same 1.12.7 pin as the devcontainer, AD-7). No `init` or `validate`: that needs providers and network and belongs to Story 6.1 (CI static checks). `fmt` on an empty folder exits 0 (verified).
- Tasks (`cloud-configs/taskfile.yml`, `dir: cloud-configs` in the include): `digital-ocean:init`, `digital-ocean:plan`, `digital-ocean:apply`, `digital-ocean:fmt`, all `tofu -chdir=digital-ocean/opentofu ...`. No destroy task: volume and reserved IP are protected by `prevent_destroy` (Story 2.5). Ansible tasks come with Epic 3.
- Empty folders are kept with `.gitkeep` (already allowed by ls-lint). Real `.tf` files arrive in Story 2.4.
- `.gitignore`: ignore `.terraform/` and `*.tfstate*` (local state holds secrets and stays out of git; the remote backend comes in Epic 6). `.terraform.lock.hcl` stays tracked (Story 2.4 commits it).
- Files: `cloud-configs/**`, `taskfile.yml`, `docker-compose.yml`, `.github/workflows/pipeline.yml`, `.folderslintrc`, `.ansible-lint.yml` or the `lint-ansible` command, `.gitignore`, `docs/cloud/digital-ocean/tasks-and-linters.md`, `mkdocs.yml`.
- Continuity from 2.1: `docs/cloud/**` is already allowed by folderslint; nav item "Cloud - Digital Ocean" exists.

### Results

- `ansible-lint` covers the folder by adding `cloud-configs` to the `lint-ansible` command in `docker-compose.yml` (no `.ansible-lint.yml` change needed).
- `plan` and `apply` have a precondition on `DIGITALOCEAN_TOKEN` that points at the API token page.
- Verified: `task --list` shows `cloud:digital-ocean:{init,fmt,plan,apply}`; `lint-opentofu`, `lint-folders`, `lint-filenames`, `lint-yaml`, `lint-ansible`, `lint-markdown-links` pass; `lint-opentofu` fails (exit 3) on a badly formatted `.tf`; `lint-folders` fails on an unknown folder under `cloud-configs/digital-ocean`; `plan` without the token stops with the docs hint; `init` on the empty folder exits 0.
- Not verified here: the CI `lint` matrix run with the new `opentofu` entry (runs on push).

## Review Triage Log

- false: `init` would make folderslint fail on `.terraform/` -- simulated a provider and module tree under `opentofu/.terraform/`; `lint-folders`, `lint-filenames` and `lint-opentofu` all exit 0 (gitignored dirs are skipped).
- false: `tofu fmt -recursive` would check module sources in `.terraform/` -- a badly formatted `.tf` under `.terraform/modules/` did not fail `lint-opentofu`.
- medium (patched): `.gitignore` missed `*.tfvars`, `*.tfvars.json` and crash logs -- added.
- low (patched): docs claimed the linter image is pinned to the devcontainer version; reworded to "keep in sync". Sync automation deferred (Dependabot `devcontainers`).
- low (deferred): no `terraform` Dependabot ecosystem -- nothing to bump until Story 2.4 adds the provider.
- low (deferred): `.github/copilot-instructions.md` lint list and conventions do not mention `cloud-configs` -- agent-instruction edit, deferred.
- low (rejected): `apply` does not apply a saved plan -- saved plan files can hold secrets and add handling; interactive `apply` shows the plan and asks before changing anything.
- low (rejected): no `init` guard and no local `validate` task -- `tofu` already prints "run tofu init"; validate is planned for Story 6.1.
- low (patched): docs did not say `init` comes first, where state lives, or that Ansible content arrives with Epic 3 -- added.
