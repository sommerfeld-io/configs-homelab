---
title: 'Swap and Alloy on the droplet with environment and stage labels'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_commit: '4fbdb944ed5b8e47d779cc3ada064b432fc216eb'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The 1 GB droplet has no swap and reports nothing to Grafana Cloud, so memory pressure kills it silently and it cannot be told apart from homelab nodes (CAP-2, CAP-4, Story 3.2).

**Approach:** Extend `provision.yml` with a swap file and Grafana Alloy installed as a systemd service through the `grafana-cloud` role, so OS metrics, logs and the app's `:8080/metrics` carry `environment=digital-ocean` and `stage=prod`. **Decision (cloud-owned config over the fleet install):** the fleet `alloy` role installs and starts Alloy; a new cloud role then overwrites `/etc/alloy/config.alloy` with its own template and restarts Alloy. The cloud template has OS metrics, journal logs, Docker logs, cAdvisor, the app scrape at `:8080/metrics` and the labels `environment=digital-ocean` and `stage`, and none of the GitHub, Ollama, FRITZ!Box or fleet-management blocks. Nothing under `configs-homelab/` changes. Document it under `docs/cloud/digital-ocean`.

## Boundaries & Constraints

**Always:** Reuse `configs-homelab/ansible/roles/grafana-cloud/alloy` through a relative path. Secrets come from `configs-homelab/ansible/vars/grafana-vault.yml`; the provision task asks for the vault password like the fleet tasks (`--ask-vault-pass`). `stage` reaches Ansible only through OpenTofu's tag and name (`prod-fantasy-hockey`): compose it in the inventory from the name prefix, never hard-code `prod` in a playbook or template. Cloud-specific roles go under `configs-cloud/digital-ocean/ansible/roles` (swap file). The cloud-owned tasks (swap, the cloud config) report no change on a second run; the fleet `alloy` role always reports changes (its restart task is `state: restarted` and its template is forced), which is accepted. Keep the new folders allowed in `.folderslintrc` and the YAML lint-clean. Docs updated in the same change; run every command the docs show once first.

**Never:** No change under `configs-homelab/` (the fleet template only changes in Story 3.3). No DO firewall, user-data scripts or app deployment. No `tofu apply`, no change to droplet size.

## I/O & Edge-Case Matrix

| Scenario            | Input / State                      | Expected Output / Behavior                                                    | Error Handling                          |
|---------------------|------------------------------------|-------------------------------------------------------------------------------|-----------------------------------------|
| First provision     | Droplet without swap and Alloy     | Swap file active, `alloy` service running                                     | N/A                                     |
| Second provision    | Already provisioned                | Swap and cloud config tasks unchanged; fleet role tasks may report changed    | N/A                                     |
| Labels              | Alloy running, series in Grafana   | OS metrics and logs carry `environment=digital-ocean`, `stage=prod`           | Query shown in docs                     |
| App metrics         | App not deployed yet (Epic 4)      | Scrape of `:8080/metrics` reports `up=0`, no Alloy error                      | N/A                                     |
| Vault password      | Not supplied                       | Task asks for it                                                              | Playbook fails before changing anything |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- add the swap and Alloy roles after `docker` and `bash` (relative `include_role`, same style); `vars_files` add `../../../../configs-homelab/ansible/vars/grafana-vault.yml`.
- `configs-cloud/digital-ocean/ansible/inventory/digitalocean.yml` -- `compose` already sets `ansible_host`, `ansible_user`; add `stage` from the name prefix (`do_name.split('-')[0]`) and an `environment` value.
- `configs-cloud/digital-ocean/ansible/vars/main.yml` -- `default_user: root`, `ps1_root`; add `alloy_environment`/`alloy_stage` style variables as the chosen option needs.
- `configs-cloud/digital-ocean/ansible/roles/alloy-config/` (new) -- `templates/config.alloy.j2` (cloud config) and `tasks/main.yml`: template to `/etc/alloy/config.alloy` (owner root, group alloy, mode as the fleet role) and restart Alloy only when the file changed (handler or `when: ... is changed`). Include it right after the fleet `alloy` role. Validate with `lint-alloy-config`. Reuse the fleet template's remote_write, loki.write, node exporter, journal and Docker blocks (copy, keep the same env var names). Labels via `prometheus.relabel`/`loki.relabel` rules or `external_labels` set to `environment` and `stage`.
- `configs-cloud/digital-ocean/ansible/roles/swap/tasks/main.yml` (new) -- swap file: size, `fallocate`/`mkswap`/`swapon`, `/etc/fstab` entry; no existing swap role in the repo (searched `configs-homelab/ansible`); must be idempotent. Size is a choice for the implementer (1 GB droplet); record it.
- `configs-homelab/ansible/roles/grafana-cloud/alloy/tasks/main.yml` -- installs Alloy from the Grafana APT repo (Debian), capabilities, systemd override, writes `/etc/alloy/config.alloy` from `templates/config.alloy.j2`, env file from vault vars, restarts Alloy, adds the alloy user to `docker`, cron watchdog for `default_user`, writes `github.token` from `GITHUB_TOKEN`. Do not edit.
- `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2` -- shared fleet template; also linted by `lint-alloy-config` (`grafana/alloy:v1.20.1 validate`). Any new cloud template needs the same validation.
- `configs-homelab/ansible/playbooks/grafana-agents.yml` -- fleet pattern: `vars_files: ../vars/grafana-vault.yml`, `include_role: ../roles/grafana-cloud/alloy`. Do not edit.
- `configs-cloud/taskfile.yml` -- `digital-ocean:ansible:provision` (and `inventory`): add `--ask-vault-pass`; `digital-ocean:deploy` runs it.
- `.folderslintrc` -- add `configs-cloud/*/ansible/roles` and its sub-folders (`swap`, `alloy-config` with `tasks`, `templates`); `docker-compose.yml` `lint-alloy-config` -- validate the cloud template too.
- `docs/cloud/digital-ocean/provisioning.md`, `index.md` (diagram, resources), `mkdocs.yml` -- document swap, Alloy, the labels and how to verify them in Grafana Cloud.
- Planning facts to keep consistent: `epic-3-context.md`, `SPEC.md` (CAP-2, CAP-4), `platform-decisions.md` (Observability) if the chosen option changes them.

## Tasks & Acceptance

**Execution:**
- [x] `configs-cloud/digital-ocean/ansible/roles/swap/` -- idempotent swap file role -- survive memory pressure
- [x] `configs-cloud/digital-ocean/ansible/playbooks/provision.yml`, `vars/main.yml`, `inventory/digitalocean.yml` -- run swap and Alloy, vault vars, derive `stage` and `environment` -- Story 3.2 wiring
- [x] `configs-cloud/digital-ocean/ansible/roles/alloy-config/` -- cloud-owned Alloy config template and tasks -- labels `environment=digital-ocean`, `stage=prod`, scrape `:8080/metrics`
- [x] `configs-cloud/taskfile.yml`, `.folderslintrc`, `docker-compose.yml` -- vault prompt, new folders, Alloy validation of the cloud template
- [x] `docs/cloud/digital-ocean/*`, `mkdocs.yml` -- document swap, Alloy and labels

**Acceptance Criteria:**
- Given `provision.yml`, when it runs, then a swap file exists and Alloy runs as a systemd service via the `grafana-cloud` role.
- Given Alloy is running, when I query Grafana Cloud, then OS metrics, logs and the app's `:8080/metrics` carry `environment=digital-ocean` and `stage=prod`.
- Given a second run, when it finishes, then the swap and cloud config tasks report no change and `swapon --show` still lists one swap file.
- Given `task lint`, when it runs, then all linters pass.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- low (patch): `tasks-and-linters.md` sentence starts in lowercase after my rewording of the token note (blind). Fixed.
- medium (defer): no automated check renders the cloud template or the inventory `stage`/`environment` values, or asserts swap and the active config on the droplet (verification-gap, blind). Needs a Molecule or InSpec scenario for cloud nodes, or a real droplet; manual Grafana queries are in the docs.
- medium (defer): `provision.yml` is excluded from ansible-lint because lint cannot decrypt `grafana-vault.yml`, same as the fleet playbooks (edge-case, blind, verification-gap). Tracked by the existing TODO issue #172; the new roles stay linted.
- false: journal logs need the alloy user in `systemd-journal` and `docker` (edge-case, blind). The fleet role already adds `alloy` to `docker`, and fleet nodes ship journal logs with the same package and config block.
- false: restart happens only when the config changed (edge-case claim). The spec and docs state the opposite for this option: the fleet role rewrites `config.alloy` each run, so the copy and the restart report changed every run (accepted when you chose option 1).
- low (rejected): the fleet config runs briefly with the wrong labels on every run, two restarts per run (blind, edge-case). The known cost of the chosen cloud-owned option, explained before approval.
- low (rejected): `alloy-config` relies on facts set by the fleet role, run order only in a comment (verification-gap). Both run in one play in a fixed order; a guard adds complexity.
- low (rejected): `stage` from `do_name.split('-')[0]` for names without a hyphen (blind, edge-case, verification-gap). OpenTofu builds every name as `<stage>-<key>`.
- low (rejected): `--ask-vault-pass` blocks CI (blind). Decided in the spec; CI auth comes in Epic 6.
- low (rejected): no `alloy validate` on the host, hardcoded Grafana endpoints copied from the fleet template, cAdvisor and app scrapes at `up=0`, no `job_name` on the node scrape (blind, edge-case). Static validation covers the template, the endpoints are the fleet's own values, `up=0` is expected until Epic 4 and 5, the scrape block is copied from the fleet.
- low (rejected): swap role gaps (resize, free space, `dd`, swappiness, check mode, `fstab` mode) and docs gaps (diagram wording, rotation guidance, troubleshooting) (blind, edge-case). Unlikely on a fresh 1 GB droplet or cosmetic; fixes add branches.
- low (rejected): `docker-compose.yml` entrypoint relies on `sh` and `alloy` in the image (verification-gap, edge-case). It ran and validated both templates in `task lint`.

## Design Notes

`stage` source: the droplet name is `<stage>-<key>` and the tags are an unordered list, so the name prefix is the dependable single source; it still comes from OpenTofu only.

## Verification

**Commands:**
- `ansible-playbook --syntax-check -i configs-cloud/digital-ocean/ansible/inventory configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- expected: success.
- `ansible-inventory -i configs-cloud/digital-ocean/ansible/inventory --host prod-fantasy-hockey` -- expected: `stage` and `environment` values present.
- `docker compose up lint-alloy-config --exit-code-from lint-alloy-config` -- expected: both the fleet and the cloud template validate.
- `task lint` -- expected: all pass.

**Manual checks (if no CLI):**
- User runs `task cloud:digital-ocean:ansible:provision` twice (agent SSH is blocked): `swapon --show` lists the file, `systemctl is-active alloy` is `active`, `/etc/alloy/config.alloy` is the cloud one, the second run shows no change for the swap and cloud config tasks.
- User queries Grafana Cloud, e.g. `up{environment="digital-ocean", stage="prod"}` and a Loki query with the same labels; the docs record the queries.
