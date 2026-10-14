---
title: 'cAdvisor on the DigitalOcean droplets through provision.yml'
type: 'feature'
created: '2026-10-14'
status: 'done'
route: 'dispatch'
baseline_commit: '6615d4490d39f1932d27b3ba0b021b474ca13f86'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The homelab machines run cAdvisor (`grafana-cloud/exporters`) and their Alloy scrapes it, but the droplets do not. The droplet's Alloy has the `integrations/cadvisor` scrape on `localhost:9110`, and it reports `up=0`.

**Approach:** Run the existing homelab role `configs-homelab/ansible/roles/grafana-cloud/exporters` from `configs-cloud/digital-ocean/ansible/playbooks/provision.yml`, after Docker and before Alloy (the same order as `grafana-agents.yml`), so every Ubuntu droplet runs cAdvisor and Alloy picks it up unchanged.

## Boundaries & Constraints

**Always:**

- Reuse the homelab role through a relative `include_role` path, as `provision.yml` already does for `docker`, `packages` and `alloy`. Don't copy it into `configs-cloud`.
- The homelab behaves as before: cAdvisor stays on `0.0.0.0:9110`. A new `.env` file and one restart on the first run after the change are acceptable.
- Decision (2026-10-14, user): on the droplet cAdvisor binds to `127.0.0.1:9110` only. The exporters role gets a bind-address variable (default `0.0.0.0`), and `configs-cloud/digital-ocean/ansible/vars/main.yml` sets `127.0.0.1`.
- A second provision run changes nothing.
- No Molecule test container gets privileged, systemd or host mounts. The exporters role needs Docker, so it is checked on the droplet, like `swap`.

**Never:** a DigitalOcean firewall; changes to the Alloy scrape config beyond comments; `ollama-metrics` or other host-specific exporters.

## I/O & Edge-Case Matrix

| Scenario        | Input / State                          | Expected Output / Behavior                                                                      | Error Handling                          |
|-----------------|----------------------------------------|-------------------------------------------------------------------------------------------------|-----------------------------------------|
| First provision | Droplet with Docker, no cAdvisor       | `cadvisor` container runs on `127.0.0.1:9110` only, compose in `/opt/grafana-cloud/exporters`, Alloy `integrations/cadvisor` target `up=1` | Role asserts the container is running   |
| Re-provision    | cAdvisor already running               | `changed=0` for the exporters tasks                                                             | N/A                                     |
| Homelab run     | `grafana-agents.yml` on any homelab host | Same compose result as before this change                                                     | N/A                                     |

</frozen-after-approval>

## Code Map

- `configs-homelab/ansible/roles/grafana-cloud/exporters/` -- `defaults/main.yml` (`exporters_path`), static `files/docker-compose.yml` (cAdvisor `v0.55.1`, `privileged: true`, `9110:8080`, Dependabot-tracked), `tasks/main.yml` (directory and compose file owned by `default_user`, compose up `pull: missing`, restart on change, `docker_container_info` assert), and `README.md`.
- `configs-homelab/ansible/playbooks/grafana-agents.yml:3-14` -- the homelab order: exporters, then alloy.
- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- add the include between "Install Docker" and "Install Alloy". It has `default_user: root` from `vars/main.yml`.
- `configs-cloud/digital-ocean/ansible/requirements.yml` -- `community.docker` 5.4.0 is already pinned (Story 4.1).
- `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2:193-231` -- the cAdvisor scrape on `localhost:9110`. Only its comment ("shows up=0 while no cAdvisor runs") changes.
- `docs/cloud/digital-ocean/provisioning.md` (role order, Alloy section with "The same applies to cAdvisor while no cAdvisor container runs"), `docs/cloud/digital-ocean/tests.md` (roles without a scenario), `docs/cloud/digital-ocean/index.md` (overview of what provisioning installs), `docs/ansible/roles/grafana-cloud/exporters.md` if the role changes.

## Tasks & Acceptance

**Execution:**

- [x] `configs-homelab/ansible/roles/grafana-cloud/exporters/` -- add `exporters_cadvisor_bind_address: 0.0.0.0` to `defaults/main.yml`. In `files/docker-compose.yml` publish `${CADVISOR_BIND_ADDRESS:-0.0.0.0}:9110:8080`; the file stays static so Dependabot keeps bumping it. In `tasks/main.yml` template a `.env` (`CADVISOR_BIND_ADDRESS={{ exporters_cadvisor_bind_address }}`, owner `default_user`, mode 0644) into `exporters_path` and add its `changed` to the restart condition. Update `README.md` and `docs/ansible/roles/grafana-cloud/exporters.md`.
- [x] `configs-cloud/digital-ocean/ansible/vars/main.yml` -- set `exporters_cadvisor_bind_address: 127.0.0.1` with a comment: the droplet has a public IP and no firewall, and Alloy scrapes `localhost:9110`.
- [x] `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- include `../../../../configs-homelab/ansible/roles/grafana-cloud/exporters` between Docker and Alloy, named like the other tasks.
- [x] `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- update the cAdvisor comment: provisioning runs cAdvisor.
- [x] Docs: `provisioning.md` (role order, the cAdvisor sentence), `tests.md` (exporters checked on the droplet, needs Docker), `index.md` (what provisioning installs). Check these pages for drift.
- [ ] HUMAN: run `task cloud:digital-ocean:ansible:provision` twice (second run without changes in the exporters tasks); check `docker ps` lists `cadvisor` with `127.0.0.1:9110->8080/tcp`, `curl -s -o /dev/null -w '%{http_code}' http://<reserved-ip>:9110/` from outside fails to connect, and Grafana Cloud has `up{job="integrations/cadvisor", environment="digital-ocean", stage="prod"} == 1`.

**Acceptance Criteria:**

- Given a clean checkout, when `task lint` and `task cloud:molecule:test` run, then both pass.
- Given a provisioned droplet, when provision runs again, then the exporters tasks report no change and `cadvisor` keeps running.
- Given the droplet runs cAdvisor, when querying Grafana Cloud, then `integrations/cadvisor` series arrive with `environment=digital-ocean` and `stage=prod`, including container metrics of `fantasy-hockey-app` and `fantasy-hockey-nginx`.

## Implementation Notes

- `.env` is written with `ansible.builtin.copy` and `content:` instead of a separate template file; same result, no new file in the role.
- The explicit `0.0.0.0` publishes cAdvisor on IPv4 only; the old short form `9110:8080` also published on `[::]:9110`. Alloy scrapes `localhost:9110`, which falls back to `127.0.0.1` (the droplet's `127.0.0.1:8080` app scrape reports `up=1` the same way).
- `task lint` and `task cloud:molecule:test` passed (implementation agent).

## Spec Change Log

## Review Triage Log

Loop 0. Reviewers: blind-hunter (BH), edge-case-hunter (EC), verification-gap (VG).

| #  | Source  | Finding                                                                              | Verdict | Evidence                                                                                                                                     | Route  |
|----|---------|--------------------------------------------------------------------------------------|---------|----------------------------------------------------------------------------------------------------------------------------------------------|--------|
| 1  | VG, BH  | Nothing checks the droplet's cAdvisor port is bound to loopback                      | medium  | Filed by VG: the only role check asserts `State.Running`; the compose fallback `:-0.0.0.0` hides a lost or renamed variable                   | patch  |
| 2  | BH      | Restart on `.env` change is redundant; docs say the restart applies the bind address | low     | `state: present` (compose up) already recreates on a changed port mapping; `state: restarted` keeps the old bindings                          | patch  |
| 3  | BH, EC  | Homelab loses the IPv6 listener `[::]:9110`                                          | low     | Short form `9110:8080` published both; `0.0.0.0:9110:8080` is IPv4 only. Frozen intent keeps `0.0.0.0`; Alloy's `localhost` falls back to IPv4 | patch (document) |
| 4  | BH      | cAdvisor starts before the swap file on the 1 GB droplet; order claim in docs is off  | low     | `provision.yml` runs exporters before `swap`; `provisioning.md` claims the `grafana-agents.yml` order                                          | patch  |
| 5  | BH      | Stale "deployed in Epic 4; until then up=0" app comment in the Alloy template        | low     | `config.alloy.j2:234`; Story 4.1 is done                                                                                                     | patch  |
| 6  | BH      | Scrape `localhost:9110` should be `127.0.0.1:9110`                                   | low     | Frozen Never: no Alloy scrape changes beyond comments; the droplet app scrape on `localhost:8080` (bound to 127.0.0.1) reports `up=1`         | reject |
| 7  | EC, BH  | Empty or IPv6 bind address not validated                                             | low     | An empty or wrong value now fails the bind check of #1; IPv6 values are not used anywhere                                                    | reject |
| 8  | BH      | Privileged cAdvisor with the Docker socket on an internet-facing droplet             | low     | With #1 and the loopback binding the container is not reachable from outside; same image and mounts as the homelab                            | reject |
| 9  | BH      | Fallback `0.0.0.0` defined twice                                                     | low     | The role always writes `.env`; #1 catches a mismatch on every run                                                                            | reject |

## Verification

**Commands:**

- `task lint` -- expected: all linters pass.
- `task cloud:molecule:test` -- expected: all cloud scenarios pass (the provision change must not break them).

**Manual checks (if no CLI):**

- The HUMAN provision runs and the Grafana query in the task list.
