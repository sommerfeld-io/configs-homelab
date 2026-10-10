---
stepsCompleted: [1, 2, 3]
inputDocuments: ['../specs/spec-fantasy-hockey-digitalocean/SPEC.md', '../specs/spec-fantasy-hockey-digitalocean/epics.md', '../specs/spec-fantasy-hockey-digitalocean/platform-decisions.md', '../specs/spec-fantasy-hockey-digitalocean/stories.yaml', 'architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md']
---

# Fantasy Hockey on DigitalOcean - Epic Breakdown

## Overview

Epic and story breakdown for running the fantasy hockey app on a DigitalOcean droplet, decomposed from `SPEC-fantasy-hockey-digitalocean` (CAP-1 to CAP-8) and its stories. Numbering continues after the completed Epic 1 ("Close the Bootstrap Debt") in `epics.md`. The spec's E1 to E5 are Epics 2 to 6 here. The spec's E6 (HTTPS), E7 (hardening) and E8 (backup) get their own breakdown later and are not in this file. Architecture rule AD-10 in the spine governs this work. Every story updates the docs under `docs/cloud/digital-ocean` in the same change (CAP-7).

## Requirements Inventory

### Functional Requirements

FR1: Operator can create the production droplet, reserved IP and 2 GB volume with OpenTofu from this repo. (SPEC CAP-1)
FR2: Operator can provision the droplet's base software with Ansible against a tag-discovered dynamic inventory, reusing existing roles. (SPEC CAP-2)
FR3: Operator can deploy the app as docker compose and reach it at a static public address. (SPEC CAP-3)
FR4: Operator can see the droplet, app and containers in Grafana Cloud, distinguished from the homelab. (SPEC CAP-4)
FR5: A change under `cloud-configs/digital-ocean` is applied by a GitHub Actions workflow. (SPEC CAP-5)
FR6: Every step runs locally and in CI through the same go-task entry points, checked by the repo's linters. (SPEC CAP-6)
FR7: The setup is documented under `docs/cloud/digital-ocean` with diagrams. (SPEC CAP-7)
FR8: Operator can replace the droplet without losing data or the URL. (SPEC CAP-8)

### NonFunctional Requirements

NFR1: `fantasy-hockey.yml` is seeded from the default template only when absent, and overwritten only from a backup. (SPEC constraint)
NFR2: `DIGITALOCEAN_TOKEN` comes locally from `vault.yml` through `bash-secrets.yml`; CI uses org-level GitHub secrets for the token and the vault password. (SPEC constraint, AD-10)
NFR3: Inventory is the DigitalOcean dynamic inventory by tag, with no static or committed inventory. (SPEC constraint)
NFR4: Only the fantasy-hockey role moves out of `ansible/`; other roles are reused through relative paths. (SPEC constraint)
NFR5: No DO firewall, user-data scripts or managed DB; one droplet; budget about $6 plus $0.20 per month. (SPEC constraint)

### FR Coverage Map

FR1: Epic 2 - droplet, IP and volume
FR2: Epic 3 - provisioning
FR3: Epic 4 - app deployment
FR4: Epic 3, Epic 5 - Alloy labels, dashboard, synthetic check
FR5: Epic 6 - GitHub Actions
FR6: Epic 2 - scaffold and linters; Epic 6 - CI checks
FR7: Every epic - docs skeleton in Epic 2
FR8: Epic 4 - replacement drill

## Epic List

### Epic 2: Droplet via OpenTofu
The droplet, reserved IP and volume exist and are managed locally with OpenTofu.
**FRs covered:** FR1, FR6, FR7

### Epic 3: Provisioning via Ansible
The droplet is provisioned from a tag-based inventory with Docker, swap and Alloy.
**FRs covered:** FR2, FR4

### Epic 4: App deployment
The app runs as docker compose on the droplet and is reachable at the reserved IP.
**FRs covered:** FR3, FR8

### Epic 5: Grafana dashboard
The droplet and app are observable in Grafana Cloud from the inside and the outside.
**FRs covered:** FR4

### Epic 6: GitHub Actions
Changes under `cloud-configs/digital-ocean` are applied by a workflow with shared state.
**FRs covered:** FR5, FR6

## Epic 2: Droplet via OpenTofu

The droplet, reserved IP and volume exist and are managed locally with OpenTofu.

### Story 2.1: Devcontainer tools and DIGITALOCEAN_TOKEN delivery

As an operator,
I want `doctl`, OpenTofu and `DIGITALOCEAN_TOKEN` available in my devcontainer,
So that I can run every DigitalOcean step locally.

**Acceptance Criteria:**

**Given** a rebuilt devcontainer
**When** I run `doctl version` and `tofu version`
**Then** both tools are installed

**Given** the token var in `ansible/vars/vault.yml` and the `bash-secrets.yml` loop in `desktop.yml`
**When** I provision my machine and open a new shell
**Then** `DIGITALOCEAN_TOKEN` is exported
**And** the docs describe the token scopes and the manual steps

### Story 2.2: cloud-configs scaffold with taskfile and linters

As an operator,
I want the `cloud-configs` folder wired into the taskfile and the linters,
So that the new setup is checked like everything else.

**Acceptance Criteria:**

**Given** `cloud-configs/taskfile.yml` included in the main taskfile with prefix `cloud`
**When** I list tasks
**Then** `cloud:digital-ocean:*` tasks are available

**Given** the new folders `cloud-configs/digital-ocean/{opentofu,ansible}`
**When** I run `task lint`
**Then** folderslint, ls-lint, ansible-lint and an OpenTofu linter cover them and pass

### Story 2.3: Docs skeleton for Cloud - Digital Ocean

As an operator,
I want a docs section for the cloud setup,
So that later stories have a place to document themselves.

**Acceptance Criteria:**

**Given** `docs/cloud/digital-ocean` and `mkdocs.yml`
**When** I build the docs
**Then** a "Cloud - Digital Ocean" nav item shows multiple pages
**And** a kroki.io diagram renders

### Story 2.4: OpenTofu droplet, SSH keys, tag and project

As an operator,
I want OpenTofu to create the production droplet,
So that the server exists without manual clicks.

**Acceptance Criteria:**

**Given** `DIGITALOCEAN_TOKEN` is set
**When** I run the OpenTofu apply task
**Then** one droplet `prod-fantasy-hockey…` exists (`s-1vcpu-1gb`, fra1, Ubuntu 26.04, monitoring on, tag `prod`, project `sommerfeld.io`) with both existing SSH keys

**Given** the droplet is applied
**When** I apply again
**Then** no changes are planned
**And** a second droplet would be a new map entry with stage defined once

### Story 2.5: Reserved IP and 2 GB volume with prevent_destroy

As an operator,
I want a reserved IP and a data volume that survive droplet rebuilds,
So that the URL and the data file persist.

**Acceptance Criteria:**

**Given** the apply task
**When** the droplet is created
**Then** a reserved IP is assigned and a 2 GB ext4 volume is attached and mounted under `/mnt/<volume-name>`

**Given** the volume and the reserved IP
**When** I run a destroy
**Then** it is blocked for both by `prevent_destroy`

## Epic 3: Provisioning via Ansible

The droplet is provisioned from a tag-based inventory with Docker, swap and Alloy.

### Story 3.1: Dynamic inventory and base provision.yml

As an operator,
I want Ansible to find the droplet by tag,
So that provisioning works on a freshly created droplet without editing an inventory.

**Acceptance Criteria:**

**Given** the dynamic inventory selecting by tag with groups `ubuntu` and `fantasy-hockey`
**When** I run the provision task against a new droplet
**Then** Docker and the bash config with the yellow `user@host` prompt are installed using roles from `ansible/roles` via relative paths

**Given** a second run
**When** provisioning finishes
**Then** nothing changes
**And** the docs explain the dynamic inventory

### Story 3.2: Swap and Alloy on the droplet with environment and stage labels

As an operator,
I want swap and Alloy on the droplet,
So that it survives memory pressure and reports to Grafana Cloud.

**Acceptance Criteria:**

**Given** `provision.yml`
**When** it runs
**Then** a swap file exists and Alloy runs as a systemd service via the `grafana-cloud` role

**Given** Alloy is running
**When** I query Grafana Cloud
**Then** OS metrics, logs and the app's `:8080/metrics` carry `environment=digital-ocean` and `stage=prod`

### Story 3.3: environment=homelab label in the homelab Alloy config

As an operator,
I want the homelab series labeled,
So that I can tell homelab from DigitalOcean in Grafana Cloud.

**Acceptance Criteria:**

**Given** `ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2`
**When** the homelab Alloy config is rendered
**Then** it carries `environment=homelab` and the existing `source` label is unchanged

## Epic 4: App deployment

The app runs as docker compose on the droplet and is reachable at the reserved IP.

### Story 4.1: Move fantasy-hockey role and deploy-services.yml with nginx

As an operator,
I want to deploy the app to the droplet with Ansible,
So that it is reachable from the internet at a static address.

**Acceptance Criteria:**

**Given** the role moved with `git mv` into `cloud-configs/digital-ocean/ansible/roles` with `fantasy_hockey_` vars
**When** I run the deploy task
**Then** the app runs as docker compose with nginx on port 80 and data under `/mnt/<volume-name>/fantasy-hockey`
**And** `http://<reserved-ip>` serves the app from outside the home network

**Given** `fantasy-hockey.yml` already exists on the volume
**When** the deploy runs again
**Then** the file is not overwritten from the default template

**Given** the role, its files, README and vault-encrypted defaults now live under `cloud-configs/digital-ocean/ansible/roles`
**When** I search `raspi.yml`, `ansible/taskfile.yml` and `.github/dependabot.yml`
**Then** none references `ansible/roles/raspi/fantasy-hockey`
**And** the `vault:fantasy-hockey` entry lives in the cloud taskfile as `cloud:digital-ocean:vault:fantasy-hockey`
**And** the Dependabot entry points at the moved `files` folder

**Given** the app is verified reachable on the droplet
**When** I run the cleanup in `raspi.yml` against pi4-0002
**Then** `/opt/fantasy-hockey` is removed
**And** the containers on that Pi are stopped and removed, after checking that no other service runs in containers there

### Story 4.2: Dependabot compose bumps for cloud-configs

As an operator,
I want Dependabot to bump the compose images (the entry itself is moved in Story 4.1),
So that updates arrive as changes under `cloud-configs/digital-ocean`.

**Acceptance Criteria:**

**Given** the Dependabot config
**When** a new image version is released
**Then** a PR changing the cloud-configs compose file is opened

### Story 4.3: Droplet replacement drill

As an operator,
I want to replace the droplet by changing the image slug,
So that an OS upgrade is one change.

**Acceptance Criteria:**

**Given** a changed image slug
**When** I apply, provision and deploy
**Then** the droplet is replaced and the reserved IP and the volume with `fantasy-hockey.yml` are re-attached
**And** the app returns at the same address after a short outage, and the procedure is documented

## Epic 5: Grafana dashboard

The droplet and app are observable in Grafana Cloud from the inside and the outside.

### Story 5.1: Grafana dashboard for the droplet and the app

As an operator,
I want one dashboard for the droplet,
So that I can investigate CPU, memory, containers and logs in one place.

**Acceptance Criteria:**

**Given** the dashboard in `grafana-cloud/manifests/git-sync/apps`
**When** it syncs to Grafana Cloud
**Then** it shows CPU, memory and more, the app, containers and logs of all containers, and no alerts

### Story 5.2: Synthetic monitoring check for the public URL

As an operator,
I want an external probe of the public URL,
So that outages on the path to the droplet become visible.

**Acceptance Criteria:**

**Given** the existing Grafana Cloud synthetic monitoring
**When** the check runs
**Then** it probes `http://<reserved-ip>` from outside, like the existing checks from Frankfurt and Paris

## Epic 6: GitHub Actions

Changes under `cloud-configs/digital-ocean` are applied by a workflow with shared state.

### Story 6.1: CI static checks for OpenTofu and Ansible

As an operator,
I want the new linters and static checks in CI,
So that broken cloud configs fail before merge.

**Acceptance Criteria:**

**Given** a change under `cloud-configs`
**When** CI runs in `pipeline.yml` or a dedicated workflow
**Then** the OpenTofu and Ansible checks run the same way as locally

### Story 6.2: Remote state with locking

As an operator,
I want shared OpenTofu state with locking,
So that localhost and GitHub Actions can alternate runs without corrupting state.

**Acceptance Criteria:**

**Given** a chosen backend (DO Spaces is the candidate)
**When** two runs start at once
**Then** the second is blocked by the lock

**Given** the existing local state
**When** I migrate it
**Then** local and CI see the same state
**And** the backend and its backup are documented

### Story 6.3: cloud-deployment.yml with org secrets and CI SSH key

As an operator,
I want a workflow that applies changes under `cloud-configs/digital-ocean`,
So that deployment is decoupled from app releases.

**Acceptance Criteria:**

**Given** a merged change under `cloud-configs/digital-ocean`
**When** `cloud-deployment.yml` runs
**Then** it runs static checks, OpenTofu, provisioning and deployment using org-level secrets (DO token, vault password, CI SSH key)

**Given** the fresh CI SSH keypair
**When** its public key is registered on DigitalOcean
**Then** the workflow connects without the local key
**And** the manual setup is documented
