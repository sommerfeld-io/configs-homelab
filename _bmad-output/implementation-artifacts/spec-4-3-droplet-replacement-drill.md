---
title: 'Droplet replacement drill'
type: 'chore'
created: '2026-10-14'
status: 'done'
route: 'dispatch'
baseline_commit: 'ca7fac369e3af3b4de92d95f29adfb62fa0e718a'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Replacing the droplet (for example for a newer Ubuntu LTS) has never been done with an existing volume and reserved IP. Nobody knows whether the volume re-mounts, the reserved IP follows, and the app comes back with its data.

**Approach:** Write the replacement procedure into the docs. Then the operator runs it once on the real droplet: replace, `task cloud:digital-ocean:deploy` (apply, provision, app deploy), checks. Fix in the same change whatever the drill shows to be broken.

## Boundaries & Constraints

**Always:**

- The volume and the reserved IP are never destroyed (`prevent_destroy` stays).
- Before the drill, the operator copies `fantasy-hockey.yml` off the droplet. The procedure says how, and the copy is never committed.
- The procedure uses the existing go-task entry points. Raw `tofu` is allowed only where no task exists.
- After the drill the app answers at the same reserved IP. `fantasy-hockey.yml` is unchanged: checksum before equals after, and it is not re-seeded.

- Decision (2026-10-14, user): the drill uses a forced replacement with the same image, `tofu -chdir=configs-cloud/digital-ocean/opentofu apply -replace='digitalocean_droplet.this["fantasy-hockey"]'`, because `ubuntu-26-04-x64` is already the newest Ubuntu slug. The page describes the `image` slug edit as the normal path for an OS upgrade; both replace the droplet the same way (`image` forces a new droplet).

**Never:** a second droplet next to the old one (create-before-destroy cannot work: a volume attaches to one droplet only); automated backups; a DigitalOcean firewall.

## I/O & Edge-Case Matrix

| Scenario            | Input / State                                              | Expected Output / Behavior                                                                                                   | Error Handling                                                         |
|---------------------|------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Replacement         | Changed image (or forced replace), volume and IP exist      | Plan: droplet and IP assignment replaced, volume and reserved IP unchanged; new droplet mounts the volume at `/mnt/prod_fantasy_hockey_data` | Plan shows a destroy of volume or IP → stop, `prevent_destroy` refuses |
| Volume not mounted  | New droplet came up without the mount                     | App deploy stops before writing (role guard)                                                                                 | Procedure says how to mount by hand, then deploy again                 |
| Host key            | Old key for the reserved IP in `known_hosts`               | Procedure removes it with `ssh-keygen -R`                                                                                    | N/A                                                                    |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/opentofu/droplets.tf` -- `image` per droplet entry; the droplet has `volume_ids` (attach at creation, so DigitalOcean mounts it) and no `create_before_destroy`.
- `configs-cloud/digital-ocean/opentofu/volumes.tf`, `reserved-ips.tf` -- `prevent_destroy` on both; the reserved IP assignment is a separate resource and is recreated for the new droplet.
- `configs-cloud/taskfile.yml` -- `digital-ocean:deploy` already runs `opentofu:apply`, `ansible:provision` and `ansible:deploy-fantasy-hockey` (two vault prompts). There is no task for `-replace`.
- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- waits for SSH and cloud-init and asserts a public IPv4, as deferred from Epic 3.
- `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/tasks/main.yml` -- mount and path guards; the seed only runs when the data file is absent.
- `docs/cloud/digital-ocean/droplet.md:80-171` -- says that changing `image` replaces the droplet, explains `-replace`, and covers the reserved IP and volume behavior on replacement. `provisioning.md:113-119` covers the host key after a replacement. `deployment.md` covers the app.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- "Prove a droplet replacement with an already existing volume and reserved IP assignment" (Story 2.5), the first-boot apt lock and the undefined `ansible_host` (Epic 3 retro).

## Tasks & Acceptance

**Execution:**

- [x] `docs/cloud/digital-ocean/replacement.md` (new, in the `mkdocs.yml` nav after Deployment) -- the procedure, in this order:
    - when to replace;
    - copy `fantasy-hockey.yml` with `scp` and record its `sha256sum`;
    - trigger the replacement: the `image` slug edit for an OS upgrade, or `-replace` with the same image (the drill);
    - read the plan: only the droplet and the IP assignment are replaced;
    - `task cloud:digital-ocean:deploy`;
    - `ssh-keygen -R` for the reserved IP and the old droplet IP;
    - checks: `findmnt`, the checksum of the data file, `http://<reserved-ip>`, `/metrics` 404, `up` for `fantasy-hockey` and `integrations/cadvisor`;
    - what to do if the volume is not mounted;
    - the expected outage.

    Link it from `index.md`, `droplet.md` (image row and replacement paragraphs) and `deployment.md`.
- [x] HUMAN: run the drill on the real droplet following the page, and report the outputs (plan summary, deploy recaps, check results, the outage duration).
- [x] Fix whatever the drill shows to be broken, and correct the page wherever reality differs from it.

**Acceptance Criteria:**

- Given the procedure, when the operator runs it, then the plan replaces only the droplet and the IP assignment, the new droplet mounts the existing volume, and the app answers at the same reserved IP with an unchanged `fantasy-hockey.yml` checksum.
- Given the replaced droplet, when `task cloud:digital-ocean:deploy` runs again, then provision and the app deploy report `changed=0`.
- Given `task lint`, when it runs, then it passes.

## Implementation Notes
- Drill run 1 (2026-10-14, by the user):
    - The plan showed "2 to add, 1 to change, 0 to destroy": the old droplet was already gone, so OpenTofu only created the new droplet and the reserved IP assignment and updated the project resources. The volume and the reserved IP were refreshed, not recreated.
    - Provision passed (`changed=39`). The app deploy stopped at the role's mount check: DigitalOcean attached the existing volume to the new droplet (web UI: attached) but did not mount it; `/mnt` was empty. The automatic mount only happens when the volume and the droplet are created together (Story 2.5).
    - Fix (user decision: in the fantasy hockey playbook, because not every droplet has this volume): `deploy-fantasy-hockey.yml` mounts `/dev/disk/by-id/scsi-0DO_Volume_<droplet-name>-data` at `/mnt/<droplet_name>_data` with `ansible.posix.mount` (pinned 2.2.2), fails when the device does not exist, and refreshes the mount facts. The tasks are tagged `volume`, and the deploy task passes extra arguments, so `-- --tags volume` mounts the volume without starting the app. The docs (replacement, deployment, droplet) no longer claim that the volume mounts automatically.
- Drill run 2 (2026-10-14, by the user): the droplet was destroyed in the web UI, then `task cloud:digital-ocean:deploy` ran.
    - Apply: "2 add, 1 change, 0 destroy" (new droplet `609117971`, reserved IP assignment, project resources); volume and reserved IP unchanged.
    - Provision: `changed=39` on the fresh droplet.
    - App deploy: the volume device existed, "Mount the volume" changed, the role's mount and path checks passed, the deploy files on the volume were unchanged, the seed was skipped (`fantasy-hockey.yml` found), and both containers ran (`changed=6`).
- Page simplified on the user's request. A droplet is removed manually (web UI, without destroying the volume) or with `tofu apply -destroy -target='digitalocean_droplet.this["fantasy-hockey"]'`, and then set up again with `task cloud:digital-ocean:deploy`. Removing the entry from `droplets.tf` does not work, because the volume and the reserved IP come from the same entry and `prevent_destroy` refuses the plan. The pre-drill copy and the separate checksum step were dropped from the page.
- Second run after the drill (2026-10-14, by the user): `task cloud:digital-ocean:deploy` reported "No changes" in OpenTofu, `changed=0` in provision and `changed=0` in the app deploy. `http://129.212.195.118` serves the app, `/metrics` returns 404, and both `up` series (`fantasy-hockey`, `integrations/cadvisor`) are 1 after the deploy. Story done.

## Spec Change Log

## Review Triage Log

Loop 0 (review of the procedure page before the drill). Reviewers: blind-hunter (BH), edge-case-hunter (EC), verification-gap (VG, no gaps).

| #  | Source  | Finding                                                                                  | Verdict | Evidence                                                                                                           | Route  |
|----|---------|------------------------------------------------------------------------------------------|---------|--------------------------------------------------------------------------------------------------------------------|--------|
| 1  | BH, EC  | Checksum compared only after the app restarted; app writes look like data loss          | medium  | `deployment.md` Seed Rule: the app rewrites the file at runtime; the page checks after `task cloud:digital-ocean:deploy` | patch  |
| 2  | EC      | Restore advice would discard writes made after the restart                               | medium  | Same root as #1: restore only when the checksum before the app deploy differs or the file is missing              | patch  |
| 3  | BH      | Restore step has no commands and depends on the backup's date                            | medium  | Prose only under Volume Not Mounted; `$(date +%F)` differs on another day                                          | patch  |
| 4  | BH, EC  | Backup in the devcontainer home, readable, evaluated with `date` twice                   | low     | `/home/vscode` is not bind-mounted; the file holds player emails; two `$(date +%F)` calls                          | patch  |
| 5  | EC      | No restart of the stopped stack when the plan is rejected or apply fails                 | low     | Only an earlier section mentions `docker compose start`                                                            | patch  |
| 6  | EC      | Broken droplet without SSH dead-ends at the copy step                                    | low     | "When to Replace" lists a broken droplet, but the first step needs SSH                                             | patch  |
| 7  | BH, EC  | Plan reading: read at the confirmation prompt; nothing else may change                   | low     | `apply -replace` stops at the prompt before the Read the Plan section                                              | patch  |
| 8  | BH      | `doctl compute volume list` format lacks `ID`; droplet ID source missing                 | low     | Next command needs `<volume-id>` and `<droplet-id>`                                                                | patch  |
| 9  | BH      | OS upgrade path does not bump the Molecule image                                         | low     | `tests/molecule/base.yml` pins `ubuntu:26.04`                                                                      | patch  |
| 10 | BH, EC  | Changes the procedure cannot do (region, first volume) are not stated                    | low     | `region` is shared by volume and reserved IP (`prevent_destroy`); adding a volume is the `droplet.md` apply case   | patch  |
| 11 | BH      | Grafana check can pass on the old droplet's last samples                                 | low     | Same `instance` name before and after                                                                              | patch  |
| 12 | BH      | Host-key steps differ between `provisioning.md` and the new page                         | low     | `provisioning.md` lacks `ssh-keygen -R <reserved-ip>`                                                               | patch  |
| 13 | EC      | New droplet IP may already be in `known_hosts`                                           | low     | `accept-new` rejects a changed key                                                                                 | patch  |
| 14 | EC      | "Second deploy reports changed=0" ignores Docker `state: latest`                         | low     | The first provision of the cAdvisor change reported `changed` for the Docker packages                              | patch  |
| 15 | BH      | No volume snapshot and no rollback for a failed OS image                                 | low     | Frozen intent: a pre-drill copy of the data file is the safety net; rollback (revert slug, replace again) goes in with #9 | reject |
| 16 | BH      | No place to record outage durations; no notice to players                                | low     | The drill result goes into the spec notes and the page                                                             | reject |
| 17 | BH      | Page scope: generic title with app-specific commands                                     | low     | The page is linked as the fantasy hockey droplet procedure; cosmetic                                               | reject |
| 18 | EC      | fstab grep matches commented lines                                                       | low     | Fallback path only, on a fresh droplet with no such line                                                           | reject |

## Verification

**Commands:**

- `task lint` -- expected: all linters pass.

**Manual checks (if no CLI):**

- The HUMAN drill and its checks from the new page.
