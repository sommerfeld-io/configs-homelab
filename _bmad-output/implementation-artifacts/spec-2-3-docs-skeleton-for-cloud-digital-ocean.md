---
title: 'Docs skeleton for Cloud - Digital Ocean'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_commit: 'ed0e75e500d9f4dd005cd8f272499cc992e4e4f0'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The "Cloud - Digital Ocean" docs section has two pages (API token, tasks and linters) but no entry page that explains what runs where, and no kroki.io diagram, so later stories have no overview to extend (CAP-7, Story 2.3).

**Approach:** Add an overview page `docs/cloud/digital-ocean/index.md` as the first nav entry of the section, with a kroki.io PlantUML diagram showing the operator workstation/devcontainer, the go-task entry points, OpenTofu and `doctl`, the DigitalOcean API, and the resources in project `sommerfeld.io` (droplet, reserved IP, volume). Link the existing pages from it.

## Boundaries & Constraints

**Always:** Inline the diagram as a ```` ```kroki-plantuml ```` fenced block (the `kroki` plugin is already enabled in `mkdocs.yml`; `mkdocs-kroki-plugin` 0.9.0 uses the `kroki-` fence prefix). Follow the repo markdown rules (padded tables, no duplicate headings, fenced code). Show resources that are not created yet as planned in the diagram and text, without story numbers.

**Never:** No `.puml` files or local kroki server. No changes to `mkdocs.yml` plugins or the docs image. No pages for later stories (inventory, provisioning, CI); they add their own. No changes to `README.md` or `docs/index.md`.

**Decision (stale docs):** Fix the docs drift from commits `a12d7ff` and `41f3e4b` in this run as a separate `fix(docs)` commit before the story commit: `api-token.md` names the shell variable `DIGITALOCEAN_ACCESS_TOKEN` (the vault key stays `DIGITALOCEAN_TOKEN`), and `tasks-and-linters.md` lists `cloud:digital-ocean:opentofu:{init,fmt,plan,apply}`.

</frozen-after-approval>

## Code Map

- `mkdocs.yml` -- nav block `Cloud - Digital Ocean` (lists `api-token.md`, `tasks-and-linters.md`); `plugins: kroki` already enabled. Add `Overview: cloud/digital-ocean/index.md` as the first entry.
- `docs/cloud/digital-ocean/api-token.md`, `docs/cloud/digital-ocean/tasks-and-linters.md` -- existing pages; style reference (H1, short H2 sections, padded tables). Link from the overview.
- `docker-compose.yml` -- services `docs-build` (`sommerfeldio/mkdocs:0.28.1`, `command: build`) and `docs-dev-server` (port 3080); use `docs-build` to verify.
- `.folderslintrc` (`docs/cloud/**`), `.ls-lint.yml` (`.md` kebab-case) -- already allow the new file; no change.
- `_bmad-output/implementation-artifacts/epic-2-context.md` -- facts for the diagram: droplet `prod-fantasy-hockey…` `s-1vcpu-1gb` fra1, tag `prod`, project `sommerfeld.io`, reserved IP, 2 GB ext4 volume at `/mnt/<volume-name>`, local state, Ansible via dynamic inventory later.

## Tasks & Acceptance

**Execution:**
- [x] `docs/cloud/digital-ocean/api-token.md`, `docs/cloud/digital-ocean/tasks-and-linters.md` -- replace the shell variable name and old task names (keep the vault key `DIGITALOCEAN_TOKEN`); commit separately as `fix(docs)` -- docs match the code before the overview links to them.
- [x] `docs/cloud/digital-ocean/index.md` -- create overview: purpose, "what runs where" kroki-plantuml diagram, short list of resources (existing vs planned), page index linking `api-token.md` and `tasks-and-linters.md` -- entry page later stories extend.
- [x] `mkdocs.yml` -- add `Overview: cloud/digital-ocean/index.md` as first item under `Cloud - Digital Ocean` -- nav shows multiple pages starting with the overview.

**Acceptance Criteria:**
- Given `docs/cloud/digital-ocean` and `mkdocs.yml`, when I build the docs, then the "Cloud - Digital Ocean" nav item shows Overview, API Token, and Tasks and Linters.
- Given the docs build, when I open the Overview page, then the kroki.io diagram renders as an image (the built HTML references kroki.io, not a raw code block).
- Given `task lint`, when it runs, then ls-lint, folderslint, yamllint and markdown-links pass.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- medium (deferred): devcontainer token chain broken -- `.devcontainer/devcontainer.json:47` maps `DIGITALOCEAN_ACCESS_TOKEN` from host `${localEnv:DIGITALOCEAN_TOKEN}`, but `desktop.yml:25` now exports only `DIGITALOCEAN_ACCESS_TOKEN`; a freshly provisioned host gets an empty token in the container. Verified by grep. Caused by `a12d7ff` (before baseline), not this story. Grouped with: api-token.md troubleshooting check passes on host but container stays empty (edge-case, blind), "docs hide the mismatch" (edge-case claim, blind), verification-gap other finding.
- medium (patched): diagram puts `terraform.tfstate` inside the devcontainer node; the workspace is a bind mount, so state lives in the repo clone on the workstation.
- low (patched): `tofu --> state` edge says "reads and writes" for all tasks; only plan and apply touch state.
- low (patched): "the only interface to DigitalOcean" overstates it (Ansible reaches the droplet over SSH later); reworded to resource management.
- low (patched): droplet row omitted Ubuntu 26.04 LTS and monitoring, both fixed in the epic.
- low (deferred): `epics-fantasy-hockey-digitalocean.md` Story 2.4 AC still says `DIGITALOCEAN_TOKEN`; planning artifact drift from `a12d7ff`, not this story.
- low (rejected): diagram does not show the vault -> playbook -> .bashrc -> containerEnv token path -- the overview links the API Token page that documents it; adding a lane adds diagram complexity.
- low (rejected): table omits `prevent_destroy` and SSH keys -- Stories 2.4/2.5 document their own resources in the same change (epic rule).
- false: droplet name differs between diagram (`prod-fantasy-hockey...`) and table ("starting with") -- the ellipsis means the same thing.
- low (rejected): "Digital Ocean" vs "DigitalOcean" spelling -- the nav label "Cloud - Digital Ocean" is mandated by the story AC and the H1 matches it.
- low (rejected): Pages table duplicates the nav -- the spec task requires a page index; one row per new page is a small cost.
- low (rejected): `init` registry download not shown in the diagram -- negligible for an overview.

## Verification

**Commands:**
- `docker compose run --rm docs-build` -- expected: exit 0, no warnings about the new page.
- `grep -o 'kroki.io[^"]*' target/docs/site/cloud/digital-ocean/index.html | head -1` -- expected: a kroki.io image URL.
- `grep -rnE 'digital-ocean:(init|fmt|plan|apply)|export DIGITALOCEAN_TOKEN|\$\{?DIGITALOCEAN_TOKEN' docs` -- expected: no matches.
- `task lint` -- expected: all linters pass.
