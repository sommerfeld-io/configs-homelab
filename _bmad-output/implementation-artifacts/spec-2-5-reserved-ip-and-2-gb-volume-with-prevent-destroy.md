---
title: 'Reserved IP and 2 GB volume with prevent_destroy'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_commit: 'd26a90c70697055f06b29ed624b20decb295af7f'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The droplet `prod-fantasy-hockey` has only its own public IPv4 and no data disk, so a rebuild changes the address and loses the data file (CAP-1, Story 2.5).

**Approach:** Give every droplet in `local.droplets` a reserved IP and a 2 GB ext4 volume, both with `lifecycle { prevent_destroy = true }`. Attach the volume at droplet creation through `volume_ids`, assign the reserved IP through a separate assignment resource so a replacement re-assigns it, and add both to project `sommerfeld.io`. Document it under `docs/cloud/digital-ocean`.

## Boundaries & Constraints

**Always:** One `digitalocean_reserved_ip` and one `digitalocean_volume` per droplet map entry (`for_each = local.droplets`), region `local.region`. Volume: `size` from a per-entry key `volume_size_gb = 2`, `initial_filesystem_type = "ext4"`, name `<droplet-name>-data`. Attach via the droplet's `volume_ids` only (never also `digitalocean_volume_attachment`). Reserved IP assigned with `digitalocean_reserved_ip_assignment` (not the `droplet_id` argument on the IP). `prevent_destroy = true` on the volume and the reserved IP, not on the droplet or the assignment (the droplet stays replaceable, Story 4.3). Volume and reserved IP URNs added to the existing `digitalocean_project_resources`. Keep `stage` defined once and "a second droplet = one map entry". Outputs: reserved IP and volume mount path per droplet.

**Never:** No `prevent_destroy` on the droplet. No firewall, user-data, backups, remote backend, destroy task. No Ansible mount tasks (Epic 3). No volume resizing logic. No change to the SSH key handling.

**Decision (existing droplet):** Replace `prod-fantasy-hockey` in this story so the volume is attached at creation and mounted: one-time `tofu -chdir=cloud-configs/digital-ocean/opentofu apply -replace='digitalocean_droplet.this["fantasy-hockey"]'` after confirmation (no new task). The droplet is empty; its own public IPv4 changes once, and the reserved IP is the stable address from then on.

**Decision (apply):** The agent runs `init` and `plan`, shows the plan, and runs `apply` plus the second no-change `plan` only after the user confirms in chat.

## I/O & Edge-Case Matrix

| Scenario            | Input / State                          | Expected Output / Behavior                                                  | Error Handling                               |
|---------------------|----------------------------------------|-----------------------------------------------------------------------------|----------------------------------------------|
| Apply               | Token set, droplet exists              | Reserved IP and volume created, IP assigned, volume attached, project lists all | N/A                                      |
| Re-apply            | State matches DO                       | `No changes.`                                                               | N/A                                          |
| Destroy attempt     | `tofu plan -destroy`                   | Plan refused for volume and reserved IP                                     | `Instance cannot be destroyed` for both      |
| Droplet replacement | Change forcing a new droplet           | Volume re-attached, IP re-assigned, neither destroyed                       | N/A                                          |

</frozen-after-approval>

## Code Map

- `cloud-configs/digital-ocean/opentofu/droplets.tf` -- `locals.droplets` entries (`size`, `image`, `resize_disk`), `digitalocean_droplet.this` (`for_each`). Add `volume_size_gb = 2` per entry and `volume_ids = [digitalocean_volume.this[each.key].id]`.
- `cloud-configs/digital-ocean/opentofu/project.tf` -- `digitalocean_project_resources.this.resources` lists droplet URNs; append volume and reserved IP URNs (`urn` is computed on both).
- `cloud-configs/digital-ocean/opentofu/outputs.tf` -- `droplet_ipv4_addresses`; add reserved IP and mount path outputs keyed by droplet name.
- Provider 2.106.0 schema: `digitalocean_volume` (`name`, `region`, `size` required; `initial_filesystem_type`, `urn`), `digitalocean_reserved_ip` (`region` required; `ip_address`, `urn`), `digitalocean_reserved_ip_assignment` (`droplet_id`, `ip_address` required). Droplet `volume_ids` is optional/computed.
- `docs/cloud/digital-ocean/droplet.md` -- attributes table, map examples (3 copies of the entry), SSH key replacement note ("once the reserved IP and the volume are added"), apply steps with expected plan counts.
- `docs/cloud/digital-ocean/index.md` -- diagram nodes and Resources table mark reserved IP and volume "planned".
- `docs/cloud/digital-ocean/tasks-and-linters.md` -- "There is no destroy task on purpose" paragraph; mention `prevent_destroy`.
- `docs/cloud/digital-ocean/api-token.md` -- scopes `block_storage`, `reserved_ip` already listed; no change.
- Mount path: DigitalOcean mounts at `/mnt/<volume-name>`, possibly with hyphens turned into underscores; record the real path after apply (SSH check by the user, the agent's SSH is blocked).
- Cost: volume about $0.20/month; a reserved IP is free while assigned.

## Tasks & Acceptance

**Execution:**
- [x] `cloud-configs/digital-ocean/opentofu/volumes.tf` (new) -- `digitalocean_volume.this` per droplet, ext4, `prevent_destroy` -- data disk.
- [x] `cloud-configs/digital-ocean/opentofu/reserved-ips.tf` (new) -- `digitalocean_reserved_ip.this` (`prevent_destroy`) and `digitalocean_reserved_ip_assignment.this` per droplet -- stable address.
- [x] `cloud-configs/digital-ocean/opentofu/droplets.tf` -- `volume_size_gb` per entry, `volume_ids` on the droplet -- attach at creation.
- [x] `cloud-configs/digital-ocean/opentofu/project.tf`, `outputs.tf` -- URNs into the project; `reserved_ip_addresses` and `volume_mount_paths` outputs.
- [x] `docs/cloud/digital-ocean/droplet.md`, `index.md`, `tasks-and-linters.md` -- reserved IP and volume sections (names, mount path, `prevent_destroy`, what survives a replacement, cost), status "declared", destroy note -- epic docs rule.

**Acceptance Criteria:**
- Given the apply task, when the droplet is created, then a reserved IP is assigned to it and a 2 GB ext4 volume is attached and mounted under `/mnt/<volume-name>`.
- Given the volume and the reserved IP, when I run `tofu plan -destroy`, then it is refused for both by `prevent_destroy`.
- Given an applied state, when I run the plan task again, then OpenTofu reports no changes.
- Given `task lint`, when it runs, then all linters pass.

## Implementation Notes

- `volume_mount_paths` derives `/mnt/<volume-name>` with hyphens replaced by underscores (`/mnt/prod_fantasy_hockey_data`); confirm with the SSH check after apply and adjust the output and docs if DigitalOcean uses another path.
- Pre-apply plan without `-replace`: `3 to add, 2 to change, 0 to destroy`. With `-replace`: `4 to add, 1 to change, 1 to destroy` (only the old droplet). `plan -destroy` cannot show the `prevent_destroy` refusal until the volume and reserved IP exist in state.
- `apply` not run yet: waits for user confirmation in chat.

- User confirmed; `apply -replace` destroyed only droplet `608504988` and created droplet `608511659` (own IPv4 `164.90.238.181`), reserved IP `129.212.195.118` (assigned), volume `prod-fantasy-hockey-data` (2 GB, attached) and the project update (4 added, 1 changed, 1 destroyed). Second plan `No changes.`; `plan -destroy` fails with `Resource instance cannot be destroyed` for the reserved IP and the volume; project lists all three.
- User SSH check: `/dev/sda ext4 1.9G ... /mnt/prod_fantasy_hockey_data` — automount works and the hyphen-to-underscore mount path is confirmed.
- Docs quoted the error as `Instance cannot be destroyed`; changed to the real `Resource instance cannot be destroyed`.

## Spec Change Log

## Review Triage Log

- medium (patch): `droplet.md` says a region change replaces only the droplet while the reserved IP and volume keep address and data; `region` forces replacement of the volume and the reserved IP too, so `prevent_destroy` blocks the plan (blind, edge-case claim). Grouped with: renaming `stage` or a map key changes the volume name (forces replacement, blocked) (edge-case); no documented way out of `prevent_destroy` when removing a map entry or retiring a volume/IP (blind, edge-case).
- low (patch): "only formatted and mounted when attached at droplet creation" — `initial_filesystem_type` formats at volume creation; only the automount needs attach-at-creation (blind, edge-case claim). Same wording in the `droplets.tf` comment.
- low (patch): the one-time `-replace` paragraph reads as a step to repeat after the normal apply; it was a one-time migration, already done (blind, edge-case). Grouped: raw `tofu` command skips the task's token check (blind, edge-case) — moot once marked as done history.
- low (patch): growing `volume_size_gb` needs `resize2fs` on the droplet; lowering it fails (blind, edge-case).
- low (patch): a replacement gives the reserved IP a new SSH host key; `ssh-keygen -R <reserved-ip>` needed (blind). Verified: the droplet behind the same reserved IP is new, so its host key differs from any earlier one.
- low (patch): `index.md` diagram and table show `/mnt/<volume-name>`; the real path turns hyphens into underscores (blind).
- low (patch): doctl checks do not show the assignment or the attached droplet (blind). Fix: `--format IP,Region,DropletName`, `--format Name,Size,Region,DropletIDs`.
- medium (defer): only `fmt -check` runs on the new resource graph (verification-gap). Already recorded for Story 6.1.
- medium (defer): no repeatable check that `prevent_destroy` still refuses a destroy (verification-gap). Needs real state; Epic 6.
- medium (defer): replacement with an already existing volume and assignment is unproven; this run created both in the same apply (verification-gap). Story 4.3 drill.
- low (rejected): "Always connect through the reserved IP" vs the inventory plugin returning the droplet IP (blind). Epic 3 inventory story decides host addressing.
- low (rejected): volume not tagged with the stage (blind). Not required; reserved IPs cannot be tagged; inventory uses droplet tags; adds a prod apply.
- low (rejected): `volume_mount_paths` is computed, not measured (blind, edge-case claim). The user's SSH check confirmed `/mnt/prod_fantasy_hockey_data`.
- low (rejected): invalid map key fails only at the API (edge-case). Unlikely; fix adds a check block.
- low (rejected): a failed replacement can leave the reserved IP unassigned (edge-case). Re-running apply recreates the assignment; guard not possible with a shared volume.
- false: spec missing from the diff (blind). Excluded on purpose so reviewers judge the code; the spec exists.

## Verification

**Commands:**
- `tofu -chdir=cloud-configs/digital-ocean/opentofu validate` -- expected: success.
- `task cloud:digital-ocean:opentofu:plan` -- expected: creates volume, reserved IP, assignment; updates droplet and project resources; with `-replace`, the droplet is replaced (1 to destroy: the old droplet only), and the volume and reserved IP are created, not destroyed.
- `tofu -chdir=cloud-configs/digital-ocean/opentofu plan -destroy` -- expected: error `Resource instance cannot be destroyed` for the volume and the reserved IP.
- After apply: `doctl compute reserved-ip list`, `doctl compute volume list`, `doctl projects resources list 83cd0efa-196d-4ed1-9d79-cb8e7d92c692` -- expected: IP assigned to the droplet, volume attached, both in the project; second plan `No changes.`
- `task lint` -- expected: all pass.

**Manual checks (if no CLI):**
- User: `ssh root@<reserved-ip> 'df -hT | grep /mnt'` -- expected: ext4, about 2 GB, mounted under `/mnt/`.
