# Epic 3 Context: Provisioning via Ansible

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Provision the DigitalOcean droplet created in Epic 2 from a tag-based dynamic inventory, so a freshly created or replaced droplet reaches its base configuration without editing any inventory: Docker, the bash prompt, swap, Grafana Alloy telemetry and a login banner. It also labels homelab telemetry so homelab and DigitalOcean series can be told apart in Grafana Cloud. Later epics deploy the app and build the dashboard on top of this base.

## Stories

- Story 3.1: Dynamic inventory and base provision.yml
- Story 3.2: Swap and Alloy on the droplet with environment and stage labels
- Story 3.3: environment=homelab label in the homelab Alloy config
- Story 3.4: Droplet MOTD with banner, live OS line and update info

## Requirements & Constraints

- Provisioning is idempotent: a second run changes nothing.
- Every story updates the docs under `docs/cloud/digital-ocean` in the same change; docs are organized by topic.
- Every step runs through go-task entry points (`cloud:digital-ocean:*`) and passes the repo linters (ansible-lint, yamllint, ls-lint, folderslint).
- No static or committed inventory. Hosts are discovered by tag, with groups `ubuntu` and `fantasy-hockey` composed from tags.
- Every Alloy series carries `environment` (`homelab` or `digital-ocean`). Only cloud series also carry `stage` (first value `prod`); the homelab has no `stage` label. The existing homelab `source` label stays unchanged.
- Alloy on the droplet ships OS metrics and logs and scrapes the app at `:8080/metrics`, with secrets from `configs-homelab/ansible/vars/grafana-vault.yml`.
- The droplet root bash prompt is the root prompt of the local ubuntu machines (`ps1_root`).
- Not allowed: DO firewall, user-data scripts, managed DB.

## Technical Decisions

- Cloud Ansible lives under `configs-cloud/digital-ocean/ansible` (own playbooks, roles, inventory config). Cloud-specific roles go in `configs-cloud/digital-ocean/ansible/roles`.
- Roles in `configs-homelab/ansible/roles` (including the `ansible-roles-collection` submodule) are reused through relative paths, not `roles_path`, and are not moved. When a local role layers on a submodule role of the same name, the submodule role is included first.
- Dynamic inventory uses the `community.digitalocean` plugin selected by tag. `DIGITALOCEAN_ACCESS_TOKEN` is passed explicitly as the plugin's `oauth_token` from an env lookup, and `tags` is added to the plugin's `attributes`. The Ansible collection is a third-party dependency and is pinned.
- `provision.yml` targets `ubuntu`; `deploy-fantasy-hockey.yml` (Epic 4) targets `fantasy-hockey`.
- `stage` is defined once in OpenTofu as the droplet tag and name, and reaches Ansible only through the tag.
- Secrets used by cloud playbooks stay vault-encrypted and share the one vault password.
- The homelab Alloy template (`config.alloy.j2`) is owned by the fleet; its only change in this epic is the `environment` label from the role variable `alloy_environment` (default `homelab`; the DigitalOcean inventory sets `digital-ocean`).
- Droplet facts from Epic 2: Ubuntu 26.04 LTS, 1 vCPU / 1 GB RAM (hence swap), user and SSH key injected by OpenTofu, data volume mounted at `/mnt/prod_fantasy_hockey_data`.

## Cross-Story Dependencies

- Story 3.1 provides the inventory and `provision.yml` that Stories 3.2 and 3.4 extend.
- Story 3.2 needs the `stage` tag and `environment` label scheme; Story 3.3 applies the matching `environment` label on the homelab side and is independent of the droplet.
- Depends on Epic 2: the droplet, its tag, SSH key and `DIGITALOCEAN_ACCESS_TOKEN` delivery.
- Downstream: Epic 4 deploys the app onto the provisioned droplet (Docker from Story 3.1); Epic 5 builds the dashboard on the labels from Stories 3.2 and 3.3; Epic 6 runs these playbooks from CI.
