---
stepsCompleted: [1, 2, 3]
inputDocuments: ['../specs/spec-fantasy-hockey-digitalocean/SPEC.md', '../specs/spec-fantasy-hockey-digitalocean/epics.md', '../specs/spec-fantasy-hockey-digitalocean/platform-decisions.md', '../specs/spec-fantasy-hockey-digitalocean/stories.yaml', 'architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md']
---

# Fantasy Hockey on DigitalOcean - Epic Breakdown

## Overview

Epic and story breakdown for running the fantasy hockey app on a DigitalOcean droplet, decomposed from `SPEC-fantasy-hockey-digitalocean` (CAP-1 to CAP-8) and its stories. Numbering continues after the completed Epic 1 ("Close the Bootstrap Debt") in `epics.md`. The spec's E1 to E5 are Epics 2 to 6 here. The spec's E6 (HTTPS) is Epic 7 here; it was pulled forward on 2026-10-15 and runs after Story 5.1 and before Story 5.2 and Epic 6. Epic 8 (DNS for `do.sommerfeld.app` in OpenTofu) was added on 2026-10-15 after the Epic 7 retro (action item 27) and runs after Epic 7 and before Epic 6. The spec's E7 (hardening) and E8 (backup) get their own breakdown later and are not in this file. Architecture rule AD-10 in the spine governs this work. Every story updates the docs under `docs/cloud/digital-ocean` in the same change (CAP-7).

## Requirements Inventory

### Functional Requirements

FR1: Operator can create the production droplet, reserved IP and 2 GB volume with OpenTofu from this repo. (SPEC CAP-1)
FR2: Operator can provision the droplet's base software with Ansible against a tag-discovered dynamic inventory, reusing existing roles. (SPEC CAP-2)
FR3: Operator can deploy the app as docker compose and reach it at a static public address. (SPEC CAP-3)
FR4: Operator can see the droplet, app and containers in Grafana Cloud, distinguished from the homelab. (SPEC CAP-4)
FR5: A change under `configs-cloud/digital-ocean` is applied by a GitHub Actions workflow. (SPEC CAP-5)
FR6: Every step runs locally and in CI through the same go-task entry points, checked by the repo's linters. (SPEC CAP-6)
FR7: The setup is documented under `docs/cloud/digital-ocean` with diagrams. (SPEC CAP-7)
FR8: Operator can replace the droplet without losing data or the URL. (SPEC CAP-8)
FR9: Users reach the app over HTTPS at `fantasy-hockey.prod.do.sommerfeld.app`, and only there, with automatically renewed certificates. (SPEC CAP-9)
FR10: Operator manages every record under `do.sommerfeld.app` declaratively with OpenTofu in a DigitalOcean DNS zone delegated from all-inkl.com, with hostnames derived from the droplets' reserved IPs. (SPEC CAP-9, AD-10 DNS)

### NonFunctional Requirements

NFR1: `fantasy-hockey.yml` is seeded from the default template only when absent, and overwritten only from a backup. (SPEC constraint)
NFR2: `DIGITALOCEAN_ACCESS_TOKEN` comes locally from `vault.yml` (vault key `DIGITALOCEAN_TOKEN`) through `bash-secrets.yml`; CI uses org-level GitHub secrets for the token and the vault password. (SPEC constraint, AD-10)
NFR3: Inventory is the DigitalOcean dynamic inventory by tag, with no static or committed inventory. (SPEC constraint)
NFR4: Only the fantasy-hockey role moves out of `configs-homelab/ansible/`; other roles are reused through relative paths. (SPEC constraint)
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
FR9: Epic 7 - DNS record and Caddy with automatic TLS
FR10: Epic 8 - delegated zone in OpenTofu and cutover from the KAS record

## Epic List

### Epic 2: Droplet via OpenTofu
The droplet, reserved IP and volume exist and are managed locally with OpenTofu.
**FRs covered:** FR1, FR6, FR7

### Epic 3: Provisioning via Ansible
The droplet is provisioned from a tag-based inventory with Docker, swap, Alloy and a login banner.
**FRs covered:** FR2, FR4

### Epic 4: App deployment
The app runs as docker compose on the droplet and is reachable at the reserved IP.
**FRs covered:** FR3, FR8

### Epic 5: Grafana dashboard
The droplet and app are observable in Grafana Cloud from the inside and the outside.
**FRs covered:** FR4

### Epic 7: HTTPS on a custom domain
The app is served only at `https://fantasy-hockey.prod.do.sommerfeld.app` through Caddy with automatic TLS. Runs after Story 5.1 and before Story 5.2 and Epic 6.
**FRs covered:** FR9, FR7

### Epic 8: DNS for do.sommerfeld.app in OpenTofu
Every record under `do.sommerfeld.app` lives in a DigitalOcean DNS zone declared in OpenTofu and delegated from all-inkl.com; no hostname-to-IP mapping is kept by hand. Runs after Epic 7 and before Epic 6.
**FRs covered:** FR10, FR7

### Epic 6: GitHub Actions
Changes under `configs-cloud/digital-ocean` are applied by a workflow with shared state.
**FRs covered:** FR5, FR6

## Epic 2: Droplet via OpenTofu

The droplet, reserved IP and volume exist and are managed locally with OpenTofu.

### Story 2.1: Devcontainer tools and DIGITALOCEAN_TOKEN delivery

As an operator,
I want `doctl`, OpenTofu and `DIGITALOCEAN_ACCESS_TOKEN` available in my devcontainer,
So that I can run every DigitalOcean step locally.

**Acceptance Criteria:**

**Given** a rebuilt devcontainer
**When** I run `doctl version` and `tofu version`
**Then** both tools are installed

**Given** the token var in `configs-homelab/ansible/vars/vault.yml` and the `bash-secrets.yml` loop in `desktop.yml`
**When** I provision my machine and open a new shell
**Then** `DIGITALOCEAN_ACCESS_TOKEN` is exported
**And** the docs describe the token scopes and the manual steps

### Story 2.2: configs-cloud scaffold with taskfile and linters

As an operator,
I want the `configs-cloud` folder wired into the taskfile and the linters,
So that the new setup is checked like everything else.

**Acceptance Criteria:**

**Given** `configs-cloud/taskfile.yml` included in the main taskfile with prefix `cloud`
**When** I list tasks
**Then** `cloud:digital-ocean:*` tasks are available

**Given** the new folders `configs-cloud/digital-ocean/{opentofu,ansible}`
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

**Given** `DIGITALOCEAN_ACCESS_TOKEN` is set
**When** I run the OpenTofu apply task
**Then** one droplet `prod-fantasy-hockey` exists (`s-1vcpu-1gb`, fra1, Ubuntu 26.04, monitoring on, tag `prod`, project `sommerfeld.io`) with the SSH key `picon___id_rsa.pub`

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
**Then** a reserved IP is assigned and a 2 GB ext4 volume is attached and mounted under `/mnt/<volume_name>` (`/mnt/prod_fantasy_hockey_data`)

**Given** the volume and the reserved IP
**When** I run a destroy
**Then** it is blocked for both by `prevent_destroy`

## Epic 3: Provisioning via Ansible

The droplet is provisioned from a tag-based inventory with Docker, swap, Alloy and a login banner.

### Story 3.1: Dynamic inventory and base provision.yml

As an operator,
I want Ansible to find the droplet by tag,
So that provisioning works on a freshly created droplet without editing an inventory.

**Acceptance Criteria:**

**Given** the dynamic inventory selecting by tag with groups `ubuntu` and `fantasy-hockey`
**When** I run the provision task against a new droplet
**Then** Docker and the bash config with the root prompt of the local ubuntu machines are installed using roles from `configs-homelab/ansible/roles` via relative paths

**Given** a second run
**When** provisioning finishes
**Then** nothing changes (`changed=0`)
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

**Given** `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2`
**When** the homelab Alloy config is rendered
**Then** it carries `environment=homelab` and the existing `source` label is unchanged

### Story 3.4: Droplet login banner (MOTD) with live OS and update info

As an operator,
I want a clean login banner on the droplet,
So that I see at a glance which host and OS I am on and whether updates are pending.

**Acceptance Criteria:**

**Given** `provision.yml` has run on the droplet
**When** I log in via SSH
**Then** the MOTD is exactly: a blank line, the ASCII art below, a blank line, the OS line, a blank line, the update info, a blank line
**And** none of the other default MOTD sections appear (help and documentation links, system information, ESM notices and so on), except the default `*** System restart required ***` notice, which is shown after the update info when a reboot is pending

```text
 ___  _      _ _        _  ___
|   \(_)__ _(_) |_ __ _| |/ _ \ __ ___ __ _ _ _
| |) | / _` | |  _/ _` | | (_) / _/ -_) _` | ' \
|___/|_\__, |_|\__\__,_|_|\___/\__\___\__,_|_||_|
       |___/
```

**Given** the OS line and the update info
**When** I log in
**Then** the OS line has the form `Welcome to <PRETTY_NAME> (GNU/Linux <kernel release> <architecture>)`, for example `Welcome to Ubuntu 26.04.1 LTS (GNU/Linux 7.0.0-31-generic x86_64)`
**And** the update info has the form `<N> updates can be applied immediately.` followed by `To see these additional updates run: apt list --upgradable`
**And** both are computed from the running system at login, not written as static text, so a later kernel change or new package updates show up without re-provisioning

**Given** a second `provision.yml` run
**When** it finishes
**Then** the MOTD tasks report no change
**And** the docs describe the MOTD and how it is built

### Story 3.5: Molecule tests for the cloud Ansible roles

As an operator,
I want every cloud role tested in a container,
So that a broken role fails in CI instead of on the droplet.

**Acceptance Criteria:**

**Given** the cloud role `motd` and the fleet Alloy role as the droplet runs it (`alloy_fleet_extras: false`, the cloud template)
**When** I run `task cloud:molecule:test`
**Then** one Molecule scenario per role under `configs-cloud/digital-ocean/tests/molecule/<role>/molecule/default/` runs converge, idempotence and verify on Ubuntu 26.04 (the droplet image), using a shared `base.yml` and `prepare.yml` in `configs-cloud/digital-ocean/tests/molecule/`
**And** `task cloud:molecule:test:<role>` runs a single scenario from `configs-cloud/digital-ocean/tests/molecule/taskfile.yml`, which `configs-cloud/taskfile.yml` includes as `molecule` (tasks `cloud:molecule:*`)

**Given** tests must never break the host
**When** any scenario runs
**Then** its container is unprivileged, has no host mounts and runs no systemd (a privileged systemd container reached the host's `/dev/tty1` and hung up the host's desktop session during every run)
**And** the `swap` role has no scenario, because `swapon` needs a privileged container; a second provision run on the droplet checks it

**Given** the fleet Alloy role manages its service through systemd
**When** the `alloy` scenario runs the fleet role with `alloy_fleet_extras: false` and `alloy_config_template` set to the cloud template `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`
**Then** `prepare` stubs `systemctl`, so the role runs unchanged, and converge sets `alloy_environment` and `alloy_stage` and test values for the Grafana Cloud secrets
**And** verify asserts that there is no `github.token` and no capabilities on the Alloy binary, and that `config.alloy` carries `environment = "digital-ocean"` and `stage = "prod"` in both `external_labels` blocks and has no `github` or `remotecfg` block

**Given** the `motd` scenario
**When** verify runs the scripts in `/etc/update-motd.d`
**Then** fixtures for the update stamp cover zero, one and several pending updates and check the exact `20-updates` output
**And** only `00-banner`, `10-os-line`, `20-updates` and `98-reboot-required` are executable

**Given** a pull request
**When** `pipeline.yml` runs
**Then** a `molecule-cloud` job runs every cloud scenario as a matrix, after linting, and gates the docs and release stages like the `molecule` job
**And** `CLAUDE.md` says a new Ansible role in this repo (local homelab roles and `configs-cloud/*/ansible/roles`) is not done without a Molecule scenario, while submodule roles are tested in the submodule
**And** the docs under `docs/cloud/digital-ocean` describe the scenarios and the tasks

## Epic 4: App deployment

The app runs as docker compose on the droplet and is reachable at the reserved IP.

### Story 4.1: Move fantasy-hockey role and deploy-fantasy-hockey.yml with nginx

As an operator,
I want to deploy the app to the droplet with Ansible,
So that it is reachable from the internet at a static address.

**Acceptance Criteria:**

**Given** the role moved with `git mv` into `configs-cloud/digital-ocean/ansible/roles` with `fantasy_hockey_` vars
**When** I run the deploy task
**Then** the app runs as docker compose with nginx on port 80 and data under `/mnt/prod_fantasy_hockey_data/fantasy-hockey`
**And** `http://<reserved-ip>` serves the app from outside the home network

**Given** `deploy-fantasy-hockey.yml` runs against the `fantasy-hockey` group and `provision.yml` is unchanged
**When** the deploy finishes
**Then** a user `fantasy-hockey` exists and is a member of the `docker` group
**And** the user has a bash config from Ansible
**And** `provision.yml` does not create the user

**Given** the app is deployed
**When** I inspect how it runs
**Then** docker compose is run by the user `fantasy-hockey`, not by `root`
**And** a second deploy run changes nothing

**Given** `fantasy-hockey.yml` already exists on the volume
**When** the deploy runs again
**Then** the file is not overwritten from the default template

**Given** the role, its files, README and vault-encrypted defaults now live under `configs-cloud/digital-ocean/ansible/roles`
**When** I search `raspi.yml`, `configs-homelab/ansible/taskfile.yml` and `.github/dependabot.yml`
**Then** none references `configs-homelab/ansible/roles/raspi/fantasy-hockey`
**And** the `vault:fantasy-hockey` entry lives in the cloud taskfile as `cloud:digital-ocean:vault:fantasy-hockey`
**And** the Dependabot entry points at the moved `files` folder

**Given** the moved role and the rule from Story 3.5
**When** I run `task cloud:molecule:test:fantasy-hockey`
**Then** a Molecule scenario for the role runs converge, idempotence and verify without the vault password
**And** the `molecule-cloud` matrix in `pipeline.yml` and the taskfile include it

**Given** the app is verified reachable on the droplet
**When** I run the cleanup in `raspi.yml` against pi4-0002
**Then** `/opt/fantasy-hockey` is removed
**And** the containers on that Pi are stopped and removed, after checking that no other service runs in containers there

### Story 4.2: Dependabot compose bumps for configs-cloud

As an operator,
I want Dependabot to bump the compose images (the entry itself is moved in Story 4.1),
So that updates arrive as changes under `configs-cloud/digital-ocean`.

**Acceptance Criteria:**

**Given** the Dependabot config
**When** a new image version is released
**Then** a PR changing the configs-cloud compose file is opened

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

**Given** the existing Grafana Cloud synthetic monitoring and the domain from Epic 7
**When** the check runs
**Then** it probes `https://fantasy-hockey.prod.do.sommerfeld.app` from outside, like the existing checks from Frankfurt and Paris
**And** it fails when the certificate is invalid or expires within 14 days

### Story 5.3: Caddy logs and certificate status on the droplet dashboard

As an operator,
I want Caddy's access, operational and certificate logs and the certificate's validity on the droplet dashboard,
So that the dashboard is the one place to watch the droplet, the reverse proxy, HTTPS and the app.

**Acceptance Criteria:**

**Given** Caddy's JSON logs, which already reach Loki through the droplet's Alloy Docker log source
**When** the cloud Alloy config is provisioned
**Then** every Caddy line carries a `log_type` label (`access`, `tls` or `operational`), with no second log pipeline and no duplicate lines
**And** access lines carry client IPs masked to /24 (IPv4) and /48 (IPv6)

**Given** the dashboard `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json`
**When** it syncs to Grafana Cloud
**Then** a Proxy row shows requests by status (Caddy's own 502s included), duration, top paths, the operational log, certificate events and the days until the certificate expires (from the Story 5.2 check), and the dashboard still has no alerts
**And** `docs/cloud/digital-ocean/monitoring.md` describes the row, the log types and the flow from Caddy to Grafana Cloud in a PlantUML diagram

## Epic 7: HTTPS on a custom domain

The app is served only at `https://fantasy-hockey.prod.do.sommerfeld.app` through Caddy with automatic TLS. Runs after Story 5.1 and before Story 5.2 and Epic 6.

### Story 7.1: DNS record for the droplet

As an operator,
I want a fixed domain that points at the droplet,
So that users reach the app by name instead of by IP.

**Acceptance Criteria:**

**Given** the reserved IP from `tofu output reserved_ip_addresses`
**When** the A record `fantasy-hockey.prod.do.sommerfeld.app` is created by hand at all-inkl.com
**Then** `dig +short fantasy-hockey.prod.do.sommerfeld.app` returns the reserved IP from outside the home network
**And** a docs page under `docs/cloud/digital-ocean` describes the record, the hostname pattern `<app>.<stage>.do.sommerfeld.app`, the manual steps at all-inkl.com and the check, and says that a droplet replacement needs no DNS change

### Story 7.2: Caddy with automatic TLS replaces nginx

As a user,
I want the app over HTTPS at its domain,
So that the connection is encrypted and the address does not change.

**Acceptance Criteria:**

**Given** the DNS record from Story 7.1
**When** the deploy runs
**Then** a Caddy container replaces nginx in the compose project, listens on ports 80 and 443, obtains and renews the certificate for `fantasy-hockey.prod.do.sommerfeld.app` automatically, and proxies to the app on `127.0.0.1:8080`
**And** the domain is derived from the droplet's stage and app name, not hard-coded per host
**And** `https://fantasy-hockey.prod.do.sommerfeld.app` serves the app, `http://` on the domain redirects to `https://`, `/metrics` returns 404, and `http://<reserved-ip>` no longer serves the app

**Given** the Caddy data folder (certificates and ACME account) on the volume
**When** the droplet is replaced
**Then** the new droplet reuses the stored certificate instead of requesting a new one

**Given** the domain does not resolve
**When** the deploy runs
**Then** it stops with a clear message before Caddy starts, so no certificate requests fail against Let's Encrypt's rate limits

**Given** the change
**When** it is done
**Then** the nginx files are gone from the droplet, the `fantasy-hockey` Molecule scenario checks the Caddyfile instead of `nginx/default.conf`, Dependabot bumps the Caddy image through the existing compose entry, and the docs (deployment, replacement checks, overview diagram, monitoring) name Caddy and the domain

## Epic 8: DNS for do.sommerfeld.app in OpenTofu

Every record under `do.sommerfeld.app` lives in a DigitalOcean DNS zone declared in OpenTofu and delegated from all-inkl.com; no hostname-to-IP mapping is kept by hand. `sommerfeld.app`, its registration and its other records stay at all-inkl.com. Runs after Epic 7 and before Epic 6, so the CI token and workflow of Epic 6 are built with the `domain` scope from the start.

### Story 8.1: DigitalOcean DNS zone do.sommerfeld.app in OpenTofu

As an operator,
I want the zone `do.sommerfeld.app` and its records declared in OpenTofu,
So that hostname-to-IP mappings follow the reserved IPs and are reviewed in a plan instead of edited by hand.

**Acceptance Criteria:**

**Given** the `droplets` map
**When** `tofu plan` runs
**Then** it creates the zone, an A record `<key>.<stage>` for each droplet with a reserved IP whose value references `digitalocean_reserved_ip.this`, and a CAA record for `letsencrypt.org`, and changes nothing else
**And** a second plan after the apply reports no changes, and a droplet replacement changes no record

**Given** the applied zone, which is not yet delegated
**When** `ns1.digitalocean.com` is queried directly
**Then** it answers authoritatively with the reserved IP, while public resolution is unchanged

**Given** the change
**When** it is done
**Then** the token has the `domain` scope, a docs page describes the zone, the record rules and the how-tos (add, update, remove, replace, move, external IP) with PlantUML architecture and update-sequence diagrams, and every manual step is listed

### Story 8.2: Delegate do.sommerfeld.app and retire the KAS record

As an operator,
I want `do.sommerfeld.app` delegated to DigitalOcean and the hand-made KAS record removed,
So that DigitalOcean is authoritative for every cloud hostname without an outage.

**Acceptance Criteria:**

**Given** three NS records `do` → `ns1`-`ns3.digitalocean.com.` created by hand in the KAS while the old A record stays
**When** the KAS and public resolvers are queried
**Then** the KAS refers to DigitalOcean, public resolvers return the reserved IP and the CAA record from the DigitalOcean zone, and records outside `do` are unchanged

**Given** the delegation verified for at least twice the KAS TTL and HTTPS verified from outside
**When** the KAS A record `fantasy-hockey.prod.do` is deleted
**Then** the app stays reachable over HTTPS with the same certificate

**Given** the change
**When** it is done
**Then** a runbook with a PlantUML migration sequence, rollback procedures and every manual step exists, and the docs, the deploy guard message and the planning docs describe the delegated zone

## Epic 6: GitHub Actions

Changes under `configs-cloud/digital-ocean` are applied by a workflow with shared state.

### Story 6.1: CI static checks for OpenTofu and Ansible

As an operator,
I want the new linters and static checks in CI,
So that broken cloud configs fail before merge.

**Acceptance Criteria:**

**Given** a change under `configs-cloud`
**When** CI runs in `pipeline.yml` or a dedicated workflow
**Then** the OpenTofu and Ansible checks run the same way as locally

**Given** `provision.yml` and every cloud playbook
**When** CI runs
**Then** each playbook passes `ansible-playbook --syntax-check` without the vault password (for example by moving the vault-free parts into imported playbooks, or giving the check a dummy vault file)
**And** a check fails when a cloud playbook uses a collection that is not pinned in `configs-cloud/digital-ocean/ansible/requirements.yml`

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
I want a workflow that applies changes under `configs-cloud/digital-ocean`,
So that deployment is decoupled from app releases.

**Acceptance Criteria:**

**Given** a merged change under `configs-cloud/digital-ocean`
**When** `cloud-deployment.yml` runs
**Then** it runs static checks, OpenTofu, provisioning and deployment using org-level secrets (DO token, vault password, CI SSH key)

**Given** the fresh CI SSH keypair
**When** its public key is registered on DigitalOcean
**Then** the workflow connects without the local key
**And** the manual setup is documented
