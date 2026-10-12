---
title: 'OpenTofu droplet, SSH keys, tag and project'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_commit: 'c993be356e0c8e239d7dd03cd5d57bf66614fe7e'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `cloud-configs/digital-ocean/opentofu` is an empty scaffold, so the production droplet for the fantasy hockey app still has to be clicked together by hand (CAP-1, Story 2.4).

**Approach:** Declare the droplet with OpenTofu: pinned OpenTofu and `digitalocean` provider with a committed lock file, local state, `stage` defined once, droplets as a `for_each` map, existing SSH keys looked up by name, tag `prod`, and assignment to project `sommerfeld.io`. Document it under `docs/cloud/digital-ocean` and let Dependabot bump the provider.

## Boundaries & Constraints

**Always:** Droplet `prod-fantasy-hockey`, `s-1vcpu-1gb`, `fra1`, image `ubuntu-26-04-x64`, `monitoring = true`, tags exactly `["prod"]`. `stage = "prod"` appears once and builds both the name prefix and the tag. A second droplet = one new map entry, no other edits. `required_version = "1.12.7"` (matches devcontainer and `lint-opentofu`); provider pinned exactly; `.terraform.lock.hcl` committed with `linux_amd64` and `linux_arm64` hashes. Token comes only from `DIGITALOCEAN_ACCESS_TOKEN` (provider reads it natively). `.tf` filenames kebab-case. Every task goes through `task cloud:digital-ocean:*`.

**Never:** No reserved IP, volume or `prevent_destroy` (Story 2.5). No firewall, user-data, backups, managed DB, remote backend, destroy task. No `digitalocean_ssh_key` resources (keys exist and are not owned by this config). No Ansible or inventory changes. No changes to the ansible-roles-collection submodule.

**Decision (SSH keys):** Inject only `picon___id_rsa.pub` (looked up by name through the API, so no local `id_rsa.pub` is needed in the devcontainer). It is the same key as the workstation's `id_rsa.pub`; the second key in the planning docs is the dedicated CI keypair added with the GitHub Actions epic. Docs note this.

**Decision (apply):** The agent runs `init` and `plan`, shows the plan, and runs `apply` plus the second no-change `plan` only after the user confirms in chat. If DigitalOcean commands fail inside the devcontainer, the user runs them on the host.

## I/O & Edge-Case Matrix

| Scenario         | Input / State                                     | Expected Output / Behavior                                            | Error Handling                          |
|------------------|---------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------|
| First apply      | Token set, empty state                            | 1 droplet + 1 project-resources assignment created                    | N/A                                     |
| Re-apply         | State matches DO                                  | `No changes.`                                                         | N/A                                     |
| Missing token    | `DIGITALOCEAN_ACCESS_TOKEN` empty                 | plan/apply task stops before calling tofu                             | Existing taskfile precondition message  |
| Unknown key name | SSH key name not registered on DO                 | plan fails on the data source                                         | Provider error names the missing key    |

</frozen-after-approval>

## Code Map

- `cloud-configs/taskfile.yml` -- `digital-ocean:opentofu:{init,fmt,plan,apply}` with the token precondition; reuse as is, no change.
- `cloud-configs/digital-ocean/opentofu/.gitkeep` -- delete once `.tf` files exist.
- `docker-compose.yml:72` `lint-opentofu` (`ghcr.io/opentofu/opentofu:1.12.7`, `fmt -check`) and `.devcontainer/devcontainer.json:34` (OpenTofu 1.12.7) -- source of the `required_version` pin; no change.
- `.gitignore` -- already ignores `.terraform/`, `*.tfstate*`, `*.tfvars`; `*.lock` does not match `.terraform.lock.hcl`. No change.
- `.github/dependabot.yml` -- add an `opentofu` ecosystem entry for `/cloud-configs/digital-ocean/opentofu` (Dependabot supports `opentofu`; the lock uses `registry.opentofu.org`, so do not use `terraform`).
- `docs/cloud/digital-ocean/index.md` -- diagram and Resources table mark the droplet "planned"; switch it to declared, add the new page to the Pages table.
- `docs/cloud/digital-ocean/tasks-and-linters.md` -- states the lock file is committed; mention the provider pin and Dependabot.
- `mkdocs.yml:100` -- `Cloud - Digital Ocean` nav; add the new page.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- the "add a terraform Dependabot ecosystem in Story 2.4" item is resolved by this story.
- Live facts (doctl, read-only): project `sommerfeld.io` exists (default project), image slug `ubuntu-26-04-x64`, size `s-1vcpu-1gb` $6, no droplets yet. Provider `digitalocean/digitalocean` latest is 2.106.0.

## Tasks & Acceptance

**Execution:**
- [x] `cloud-configs/digital-ocean/opentofu/versions.tf` -- `terraform { required_version = "1.12.7"; required_providers { digitalocean = { source = "digitalocean/digitalocean", version = "2.106.0" } } }` plus empty `provider "digitalocean" {}` -- pins and token from env.
- [x] `cloud-configs/digital-ocean/opentofu/droplets.tf` -- `locals { stage, region, droplets map }`, `data "digitalocean_ssh_key"` for each name in a key-name list (one entry: `picon___id_rsa.pub`), `resource "digitalocean_droplet" "this"` with `for_each` -- the droplet.
- [x] `cloud-configs/digital-ocean/opentofu/project.tf` -- `data "digitalocean_project"` by name + `digitalocean_project_resources` with all droplet URNs -- explicit project assignment.
- [x] `cloud-configs/digital-ocean/opentofu/outputs.tf` -- map of droplet name → public IPv4 -- operator check after apply.
- [x] `cloud-configs/digital-ocean/opentofu/.terraform.lock.hcl` -- `task cloud:digital-ocean:opentofu:init`, then `tofu providers lock -platform=linux_amd64 -platform=linux_arm64`; delete `.gitkeep` -- reproducible provider.
- [x] `.github/dependabot.yml` -- add `opentofu` entry, weekly -- provider bumps.
- [x] `docs/cloud/digital-ocean/droplet.md` (new) + `index.md` + `tasks-and-linters.md` + `mkdocs.yml` -- droplet page (attributes table, stage and map, how to add a droplet, SSH key replacement note, apply steps), overview status, nav -- epic docs rule.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- remove the resolved Dependabot item.

**Acceptance Criteria:**
- Given `DIGITALOCEAN_ACCESS_TOKEN` is set, when I run `task cloud:digital-ocean:opentofu:apply`, then one droplet `prod-fantasy-hockey` exists with `s-1vcpu-1gb`, fra1, Ubuntu 26.04, monitoring on, tag `prod`, project `sommerfeld.io` and SSH key `picon___id_rsa.pub`.
- Given the droplet is applied, when I run the plan task again, then OpenTofu reports no changes.
- Given `droplets.tf`, when a second droplet is needed, then it is one new map entry and `stage` is not repeated.
- Given `task lint`, when it runs, then all linters (including `lint-opentofu`) pass.

### Review Findings

Code review of `a528145` (2026-10-12), layers: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor.

- [x] [Review][Patch] Document that `task lint` (and the `lint-repo` pre-commit hook) formats the OpenTofu code before linting; the stale "run fmt by hand when the linter fails" line applies only to CI [docs/cloud/digital-ocean/tasks-and-linters.md:43] — decision: keep the fmt step as is (user: auto-format in pre-commit so only formatted OpenTofu reaches the remote; format OpenTofu only, lint everything)
- [x] [Review][Patch] Set `resize_disk = false` so a resize changes CPU/RAM only, never disk, as the epic requires; add it to the attributes table [cloud-configs/digital-ocean/opentofu/droplets.tf:27]
- [x] [Review][Defer] No token-free `tofu validate` in lint/CI while Dependabot provider bumps are now enabled [docker-compose.yml:76] — deferred: Story 6.1; already recorded in deferred-work.md
- [x] [Review][Defer] Three exact OpenTofu pins with no sync [cloud-configs/digital-ocean/opentofu/versions.tf:2] — deferred: epic decision for exact pins; already recorded in deferred-work.md

Rejected:

- low: empty `ssh_key_names` gives a droplet with a root password (edge-case) — unlikely, fix adds a precondition.
- low: map key with invalid hostname characters fails only at apply (edge-case) — unlikely, fix adds a precondition.
- low: empty `droplets` map leaves `digitalocean_project_resources` empty (edge-case) — unlikely, fix adds a `count` branch.
- false: no `ignore_changes = [ssh_keys]` / `prevent_destroy` on the droplet (blind) — the architecture makes OpenTofu the sole key owner and accepts replacement; Story 4.3 drills replacement.
- low: duplicate or overlapping deferred-work entries (blind) — the workflow mandates append-only entries.
- false: deferred-work entries lack blank lines (blind) — the file already mixes both styles (the spec-2-3 entries have none).
- false: reused RSA key and no firewall (blind) — the key was the user's decision; the epic forbids a DO firewall.
- low: doctl checks do not show the SSH key or compare the output IP (blind) — plan/state show `ssh_keys = ["59972151"]`; extra commands add little.
- low: "declared" vs "planned" in the diagram is ambiguous (blind) — cosmetic.
- reject: root `taskfile.yml` and `.editorconfig` not in the spec (acceptance-auditor) — deliberate user edits; fix would edit the spec.
- reject: docs say all platforms while the spec says amd64/arm64 (acceptance-auditor) — the constraint is met (registry hashes cover all platforms); fix would edit the spec.
- false: spec `done` vs sprint `review` (acceptance-auditor) — build sets the spec done and the story to review until code review, by design.
- false: AC1/AC2 not provable from the diff (acceptance-auditor) — verified live in the session: droplet `608504988` via doctl, second plan `No changes.`
- false: submodule modified (acceptance-auditor) — not part of commit `a528145`.
- false: replacement doc ahead of reality (acceptance-auditor) — the auditor itself found it correctly worded as future.

## Implementation Notes

- Implemented by a subagent: `versions.tf`, `droplets.tf`, `project.tf`, `outputs.tf`, lock file (`linux_amd64` + `linux_arm64`), `.gitkeep` removed, `opentofu` Dependabot entry, `droplet.md` + overview/tasks/nav updates, resolved deferred item removed.
- Orchestrator fix: `droplet.md` said to add keys "with Ansible instead"; changed to the architecture rule (OpenTofu is sole key owner, replacement accepted).
- Verified: `validate`, plan `2 to add, 0 to change, 0 to destroy` (droplet with ssh_keys `59972151`, project `83cd0efa-…`), missing-token precondition stops the task, unknown key name fails with `no ssh key found with name …`, `task lint` exit 0.
- User confirmed; `task cloud:digital-ocean:opentofu:apply` created droplet `608504988` (`142.93.102.167`) and the project assignment (2 added). Second plan: `No changes.` doctl: `s-1vcpu-1gb`, fra1, Ubuntu 26.04 (LTS) x64, tag `prod`, features include `monitoring`, project lists `do:droplet:608504988`. State in `cloud-configs/digital-ocean/opentofu/terraform.tfstate` (gitignored).
- Surprise: doctl has no `Size` column; fixed the check in `droplet.md` and Verification to `SizeSlug`.
- SSH login test from the agent was blocked by the permission classifier; key injection is shown by `ssh_keys = ["59972151"]` in plan/state; the user runs the login check.

- Code review fixes: `resize_disk = false` per droplet map entry (epic: resize CPU/RAM only), applied in place (`0 added, 1 changed, 0 destroyed`, droplet `608504988` unchanged), second plan `No changes.`; `tasks-and-linters.md` documents that `task lint` and the `lint-repo` pre-commit hook format OpenTofu code first.

## Spec Change Log

## Review Triage Log

- low (patch): `droplet.md` says the reserved IP and volume survive a replacement, but they do not exist until Story 2.5; today a key, image or region change replaces the droplet and changes its public IP (blind). Verified: no `digitalocean_reserved_ip`/volume in the diff.
- low (patch): `droplet.md` and `tasks-and-linters.md` say the lock has hashes for `linux_amd64` and `linux_arm64`; the lock has 16 `h1:`/16 `zh:` entries, and a single-platform `tofu providers lock` also yields 16 `h1:` because the OpenTofu registry publishes hashes for all platforms (blind, edge-case claim). Grouped.
- low (patch): `droplet.md` "run them on the host" gives no cause; and `doctl projects list` does not show where the project id comes from (blind). Fix: point to the token check on the API Token page, add `--format ID,Name`.
- medium (defer): only `tofu fmt -check` runs on `.tf`; no `init -backend=false && validate`, so broken references or a breaking Dependabot provider bump pass CI green (verification-gap, blind). Verified: `docker-compose.yml:76` is fmt only, no validate anywhere. Pre-existing linter scope from Story 2.2; Story 6.1 "CI static checks for OpenTofu and Ansible" owns it.
- medium (defer): OpenTofu is now pinned exactly in three places (devcontainer, `lint-opentofu` image, `required_version`); a devcontainer bump without `versions.tf` breaks local `init` (edge-case, verification-gap other, blind). The exact pin is an epic decision; extends the existing two-pin deferred item.
- low (defer): agent instructions do not mention `cloud-configs`, the cloud tasks or the opentofu linter (blind). Agent-context file; existing deferred entry.
- low (rejected): `task lint` now runs `opentofu:fmt`, which rewrites files before `fmt -check` and needs a host `tofu` (blind, edge-case x2, verification-gap other, edge-case claim). Real, but a deliberate user edit made during this story (auto-fix like `docs:generate` in the same task); `task lint` runs in the devcontainer where `tofu` exists, and CI calls the compose services directly (`pipeline.yml:57`). Surfaced to the user.
- false: no firewall and no follow-up recorded (blind). The epic forbids a DO firewall ("Not allowed: DO firewall").
- false: deferred `terraform` entry removed though `opentofu` was used, and leading slash in the Dependabot directory (blind). The spec Code Map records why `opentofu` replaces `terraform`; Dependabot accepts directories with a leading slash.
- low (rejected): only the stage tag, so a second app shares the inventory group (blind). Design Notes: Epic 3 adds tags if needed, and tag changes update in place.
- low (rejected): region is one local for all droplets (blind). fra1 is fixed by the epic; a per-entry override adds surface nobody needs yet.
- low (rejected): empty `droplets` map leaves `digitalocean_project_resources` with an empty list (edge-case). Unlikely in use, and the guard adds a `count` branch.
- low (rejected): empty `ssh_key_names` creates a droplet with a root password (edge-case). Unlikely; guard adds a precondition.
- low (rejected): map key with characters DO rejects fails only at apply (edge-case). Unlikely; guard adds a regex precondition.
- false: project name missing or duplicated (edge-case). The data source fails loudly when the name is missing; the live account has exactly one `sommerfeld.io`.

## Design Notes

Keys are data sources, not resources: they already exist on the account, and importing them would let a `tofu destroy` delete them. The `fantasy-hockey` and `ubuntu` inventory groups for Epic 3 are not tags here; if Epic 3 needs more tags, adding them is an in-place update, not a replacement.

```hcl
locals {
  stage    = "prod"
  droplets = { fantasy-hockey = { size = "s-1vcpu-1gb", image = "ubuntu-26-04-x64" } }
}
resource "digitalocean_droplet" "this" {
  for_each = local.droplets
  name     = "${local.stage}-${each.key}"
  tags     = [local.stage]
}
```

## Verification

**Commands:**
- `task cloud:digital-ocean:opentofu:init && tofu -chdir=cloud-configs/digital-ocean/opentofu validate` -- expected: success.
- `task cloud:digital-ocean:opentofu:plan` -- expected: 2 to add (droplet, project resources), 0 to change or destroy.
- After apply: `doctl compute droplet get prod-fantasy-hockey --format Name,SizeSlug,Region,Image,Tags,Features` and `doctl projects resources list 83cd0efa-196d-4ed1-9d79-cb8e7d92c692` -- expected: attributes and project match; second `plan` prints `No changes.`
- `task lint` -- expected: all pass.
