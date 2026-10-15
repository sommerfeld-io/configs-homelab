---
title: 'Epic 4 retro items 18-22: Docker after the volume mount, cAdvisor bind assert, doc drift'
type: 'bugfix'
created: '2026-10-15'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '70e256e19fd66e96ccfba353ab6af5b58653657b'
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-4-retro-2026-10-14.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 4 retro findings D1-D6: nothing orders `docker.service` after the fantasy-hockey volume mount (`nofail`), so a late volume lets the stack create empty `data/` and `nginx/default.conf` on the root disk (item 18); nothing checks that the droplet resolves `exporters_cadvisor_bind_address` to `127.0.0.1` (item 20); and `replacement.md`, `droplet.md`, `tests.md`, `provisioning.md` and `pipelines.md` say things that are not true (items 19, 21, 22).

**Approach:** The deploy playbook adds a systemd drop-in that ties `docker.service` to the volume mount, next to the mount task; `provision.yml` asserts the bind address before cAdvisor runs; the docs are corrected in place. All five items ship in one spec, full length kept (user decisions, 2026-10-15).

**Decision (2026-10-15):** Docker requires the mount: the drop-in sets `RequiresMountsFor=<fantasy_hockey_volume_mount>` (Requires= and After= on the mount unit). When the volume never appears at boot, `docker.service` fails its dependency and does not start; nothing is written to the root disk, the app and cAdvisor are down (`up` = 0) until the volume is back and Docker is started.

## Boundaries & Constraints

**Always:** The drop-in tasks carry the `volume` tag like the other mount tasks. Run `task lint` before committing. Keep the docs in the existing style (no relative links in role READMEs; markdownlint rules from `CLAUDE.md`).

**Never:** No change to the fleet roles under `configs-homelab/ansible/roles` (the exporters role keeps its own assert). No reboot or `tofu` apply/destroy of the real droplet by the agent: the reboot check is run by the user. No privileged test containers. No new Molecule scenario for the playbook volume tasks (deferred as D8).

## I/O & Edge-Case Matrix

| Scenario                | Input / State                                         | Expected Output / Behavior                                                    | Error Handling                                        |
|-------------------------|-------------------------------------------------------|-------------------------------------------------------------------------------|-------------------------------------------------------|
| Reboot, volume attached | droplet reboots                                       | mount unit active before `docker.service` starts; app back, `data/` on volume | N/A                                                   |
| Reboot, volume late     | device appears after `local-fs.target`                | `docker.service` waits for the mount                                          | N/A                                                   |
| Reboot, volume missing  | device never appears                                  | mount fails after the device timeout; `docker.service` does not start        | user attaches the volume, then `systemctl start docker` |
| Second deploy           | drop-in already present                               | drop-in task `ok`, no daemon-reload, `changed=0`                              | N/A                                                   |
| Lost bind override      | `exporters_cadvisor_bind_address` not set in vars     | provision fails before "Run cAdvisor"                                         | fail message names the variable and `vars/main.yml`   |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml` -- volume tasks (`stat`, assert, `ansible.posix.mount` with `defaults,nofail,discard,noatime`, fact refresh), all tagged `volume`; `fantasy_hockey_volume_mount` is a play var derived from `inventory_hostname`. Add the drop-in after "Mount the volume".
- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- "Run cAdvisor" includes the fleet `grafana-cloud/exporters` role; `vars/main.yml` sets `exporters_cadvisor_bind_address: 127.0.0.1` (role default `0.0.0.0`). Asserts in this file use `quiet: true` and a `fail_msg` that says what to check.
- `configs-homelab/ansible/roles/grafana-cloud/alloy/handlers/main.yml` -- existing `ansible.builtin.systemd_service` + `daemon_reload: true` idiom to copy.
- `configs-cloud/digital-ocean/opentofu/project.tf` -- `digitalocean_project_resources.this` lists droplet URNs, so a targeted droplet destroy destroys it too.
- `docs/cloud/digital-ocean/replacement.md` -- "Remove the Droplet" plan list; "Set It Up Again" says the apply "updates the project resources".
- `docs/cloud/digital-ocean/droplet.md:122` -- "including the data file copy and the checks".
- `docs/cloud/digital-ocean/tests.md:46,48,50` -- guards "three times" (verify.yml has four cases: not mounted, outside, `..`, sibling); swap and exporters "report no change".
- `docs/cloud/digital-ocean/provisioning.md:50,54` -- cAdvisor bind paragraph; `changed=0` caveat names only `packages`, not `docker` (`state: latest` in `ansible-roles-collection/docker/tasks/ubuntu/30-install.yml`).
- `docs/cloud/digital-ocean/deployment.md:9-13` -- volume mount bullets.
- `docs/pipelines.md:105,112,124` -- Dependabot table (exporters entry), fantasy-hockey bump paragraph, "No deployment" step.

## Tasks & Acceptance

**Execution:**
- [x] `configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml` -- after "Mount the volume", write `/etc/systemd/system/docker.service.d/fantasy-hockey-volume.conf` (root, `0644`, directory created first) with `[Unit]` `RequiresMountsFor={{ fantasy_hockey_volume_mount }}`, and run a daemon-reload only when it changed; tag both `volume`; comment why (D1) -- Docker never starts the stack before the volume is mounted.
- [x] `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- before "Run cAdvisor", assert `exporters_cadvisor_bind_address == '127.0.0.1'` with a `fail_msg` pointing at `ansible/vars/main.yml` -- a lost override can no longer publish cAdvisor.
- [x] `docs/cloud/digital-ocean/deployment.md`, `provisioning.md` -- document the drop-in (and the boot behaviour of the decision) and the bind-address assert; say that a provision run can upgrade Docker (`state: latest`) and so restart `dockerd`, the app and cAdvisor.
- [x] `docs/cloud/digital-ocean/replacement.md` -- the targeted destroy also destroys `digitalocean_project_resources.this`; the next apply recreates it (and only updates it after a web-UI destroy).
- [x] `docs/cloud/digital-ocean/droplet.md`, `tests.md` -- drop "data file copy"; four guard cases including the sibling; "no change" qualified for Docker and package releases.
- [x] `docs/pipelines.md` -- bumps to the fleet roles the droplet runs (`grafana-cloud/exporters`, `grafana-cloud/alloy`) land under `configs-homelab/` and reach the droplet only with `task cloud:digital-ocean:ansible:provision`.
- [ ] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- set items 18-22 to `done` once verified.

**Acceptance Criteria:**
- Given the deploy ran, when `systemctl show docker.service -p Requires -p After` runs on the droplet, then the volume's mount unit is listed in both.
- Given the droplet is rebooted by the user, when it is back, then `findmnt` shows the volume, the app answers at the reserved IP, and `up{job="fantasy-hockey"}` is 1.
- Given `task lint`, when it runs, then it passes.

## Implementation Notes

- Drop-in: `ansible.builtin.file` (folder `0755`) and `ansible.builtin.copy` with inline `content` (`[Unit]` `RequiresMountsFor={{ fantasy_hockey_volume_mount }}`, `0644`), then `ansible.builtin.systemd_service` with `daemon_reload: true` only when the copy changed. Docker is not restarted: it already runs after the mount task, the order only matters at the next boot. All three tasks tagged `volume`.
- Assert uses `exporters_cadvisor_bind_address | default('') == '127.0.0.1'`, so an unset variable fails with the message instead of an undefined-variable error.
- Docs also updated in the hand-written playbook pages `docs/cloud/ansible/playbooks/deploy-fantasy-hockey.md` and `provision.md`; `deployment.md` got a "Boot Order" section with the three boot cases and the `systemctl show` check.
- `sprint-status.yaml`: items 19-22 set to `done`; item 18 stays `open` until the user's droplet reboot check (acceptance criteria 1 and 2) has run.
- Verification pass: `replacement.md` bullet intro still said "only the droplet and its reserved IP assignment" next to the new three-resource list; changed to "the droplet and the resources that depend on it".
- Matrix audit: rows "Lost bind override" verified by running the extracted assert task locally (unset and `0.0.0.0` fail with the message naming `vars/main.yml`; `127.0.0.1` passes). The reboot and second-deploy rows have no automated test by design (Never: no Molecule scenario for the playbook volume tasks, D8); they are covered by the user's droplet checks under Verification.

## Spec Change Log

## Review Triage Log

| #   | Layer      | Finding                                                                                     | Verdict     | Route  | Evidence                                                                                                                                                                      |
|-----|------------|---------------------------------------------------------------------------------------------|-------------|--------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1   | VG         | Bind-address assert in `provision.yml` is not run by any automated test                     | medium      | defer  | Pre-verified gap; only a one-off local run exercised it. Needs a playbook-level test harness this change does not set up.                                                     |
| 2   | VG         | Drop-in tasks and daemon-reload have no automated test                                      | false       | reject | Out of scope by intent: frozen Never excludes a Molecule scenario for the playbook volume tasks (D8); boot order needs systemd as PID 1, which the project forbids.            |
| 3   | VG, BH     | `replacement.md` says the project-resources destroy leaves the volume and reserved IP alone | medium      | patch  | `project.tf:5-12` lists droplet, volume and reserved-IP URNs in one resource, so all three leave the project until the next apply; they stay in the account.                  |
| 4   | VG, BH     | Spec task for `sprint-status.yaml` unticked                                                 | low         | reject | Fix would edit this build's spec; handled when item 18 closes.                                                                                                                |
| 5   | BH, EC     | "Volume late" wait is unbounded in the docs and playbook comment                            | medium      | patch  | `nofail` mount, no `x-systemd.device-timeout=`: systemd waits for the device up to the default timeout (90 s), then the case behaves like "volume missing".                   |
| 6   | BH, EC     | `Requires=` stop propagation and drop-in removal undocumented                               | medium      | patch  | `RequiresMountsFor=` adds `Requires=`; stopping or unmounting the mount unit stops `docker.service` (app and cAdvisor). No documented way to drop the dependency.             |
| 7   | BH         | Reboot check missing from `replacement.md` Checks                                           | low         | patch  | Checks list has no `systemctl show docker.service -p Requires -p After` entry; direct one-line addition.                                                                      |
| 8   | BH         | Boot Order link leads to a deploy-failure section with no boot case                         | low         | patch  | `replacement.md#volume-not-attached` describes only the deploy assert message; the boot case (Docker failed its dependency) and `systemctl start docker` are missing there.   |
| 9   | BH         | `tests.md` claims the exporters role reports no change after a Docker upgrade restart       | low         | patch  | `exporters/tasks/main.yml` runs `docker_compose_v2 state: present` right after; a container still restarting may make it report a change. The new clause is unproven; drop it. |
| 10  | BH         | Missing volume takes monitoring down; no alert                                              | false       | reject | The frozen decision accepts app and cAdvisor down with `up` = 0; alerting is Epic 5.                                                                                          |
| 11  | BH         | `pipelines.md` calls Alloy changes Dependabot "bumps"                                       | low         | patch  | `.github/dependabot.yml` has no Alloy entry; Alloy changes are role edits or APT releases. Direct wording fix.                                                                |
| 12  | BH         | Assert untagged                                                                             | false       | reject | `provision.yml` uses no tags at all, so no `--tags` run can skip the assert today.                                                                                            |
| 13  | BH, EC     | Drop-in never removed when the droplet stops running fantasy-hockey                         | low         | patch  | Merged into #6: document deleting the drop-in plus `systemctl daemon-reload`; no code branch added.                                                                           |
| 14  | EC         | Docker upgrade during provision fails when the mount is inactive                            | false       | reject | `Requires=` pulls the mount job, which mounts an attached volume; with no volume Docker is already down and the run fails loudly, which is the decided behaviour.            |

## Verification

**Commands:**
- `task lint` -- expected: all linters pass.
- `task cloud:molecule:test` -- expected: unchanged scenarios still pass.

**Manual checks (if no CLI):**
- User runs `task cloud:digital-ocean:ansible:all`, then the second run reports `changed=0` for the new tasks.
- User reboots the droplet (`ssh root@<reserved-ip> reboot`) and runs the checks of `replacement.md` "Checks".
- Optional, read-only: `tofu plan -destroy -target='digitalocean_droplet.this["fantasy-hockey"]'` lists the project resources among the destroyed resources.
