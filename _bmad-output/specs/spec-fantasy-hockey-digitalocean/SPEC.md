---
id: SPEC-fantasy-hockey-digitalocean
companions: ['epics.md', 'platform-decisions.md', '../../planning-artifacts/architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md']
sources: ['../../brainstorming/brainstorm-fantasy-hockey-digitalocean-2026-10-10/brainstorm-intent.md']
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Fantasy Hockey on DigitalOcean

## Why

A pain to solve and a vision to realize. The fantasy hockey app (a hobby for about 3 users) runs on a Raspberry Pi behind a Fritzbox port forward that proved unstable: the forward was unreachable from inside the LAN (router UI shadows port 80) and external requests timed out at random while internal monitoring showed no downtime. Sebastian, the sole operator, also does not want a door into the home network. A small DigitalOcean droplet, provisioned and deployed from this repo (OpenTofu, Ansible, GitHub Actions), removes both problems, must run unattended long-term, and leaves room for more apps or a test stage later. The real long-term risk is neglect, not scale.

## Capabilities

- **CAP-1**
    - **intent:** Operator can create the production droplet and its supporting resources (reserved IP, 2 GB block volume) with OpenTofu from this repo.
    - **success:** From a clean checkout with `DIGITALOCEAN_TOKEN` set, the `cloud:digital-ocean` OpenTofu task creates one droplet `prod-fantasy-hockey…` (tag `prod`, project `sommerfeld.io`, ext4 volume mounted under `/mnt/<volume-name>`); a second run shows no changes; a destroy attempt is blocked for the volume and the reserved IP.

- **CAP-2**
    - **intent:** Operator can provision the droplet's base software with Ansible against a tag-discovered dynamic inventory, reusing existing roles.
    - **success:** Running the provision task against a freshly created droplet, with no inventory edit, results in Docker, swap, Alloy and the yellow `user@host` bash prompt in place; a second run changes nothing.

- **CAP-3**
    - **intent:** Operator can deploy the fantasy hockey app as docker compose on the droplet and reach it on a static public address.
    - **success:** After the deploy task, `http://<reserved-ip>` (port 80, nginx in front of the app on 8080) serves the app from outside the home network; a Dependabot compose-image bump followed by a redeploy updates the running containers.

- **CAP-4**
    - **intent:** Operator can see the droplet, the app and its containers in Grafana Cloud, distinguished from the homelab.
    - **success:** Grafana Cloud shows OS metrics, container metrics, logs and the app's `:8080/metrics` for the droplet, every series labeled `environment=digitalocean` and `stage=prod`; homelab series carry `environment=homelab`; a dashboard in `grafana-cloud/manifests/git-sync/apps` covers host, app, containers and logs; a synthetic monitoring check probes the public URL from outside.

- **CAP-5**
    - **intent:** A change under `cloud-configs/digital-ocean` is applied automatically by a GitHub Actions workflow, decoupled from app releases.
    - **success:** Merging a change (including a Dependabot bump) to `cloud-configs/digital-ocean` runs `cloud-deployment.yml` through static checks, OpenTofu, provisioning and deployment using only org-level secrets and shared locked state; localhost and the workflow can alternate runs without state corruption.

- **CAP-6**
    - **intent:** Every step runs locally and in CI through the same go-task entry points, checked by the repo's linters.
    - **success:** `task cloud:digital-ocean:*` tasks (from `cloud-configs/taskfile.yml` included with prefix `cloud`) run each step; `task lint` covers the new folder (folderslint, ls-lint, ansible-lint, an OpenTofu linter); the devcontainer provides `doctl` and OpenTofu.

- **CAP-7**
    - **intent:** The setup is documented well enough to operate without prior memory.
    - **success:** `docs/cloud/digital-ocean/` has multiple pages under a "Cloud - Digital Ocean" nav item in `mkdocs.yml` covering what runs where, how it works (including the dynamic inventory), how to run provisioning (GitHub Actions preferred), and manual setup for localhost, GitHub (org secrets) and DigitalOcean, with kroki.io diagrams; every epic updates the docs in the same change.

- **CAP-8**
    - **intent:** Operator can replace the droplet (for example to move to a newer Ubuntu LTS) without losing data or changing the URL.
    - **success:** Changing the image slug and rerunning the pipeline replaces the droplet; the reserved IP and the volume with `fantasy-hockey.yml` are re-attached; the app is reachable at the same address after a short outage.

- **CAP-9**
    - **intent:** (E6) Users can reach the app over HTTPS on a custom domain without the operator managing certificates.
    - **success:** `https://fantasy-hockey.do.sommerfeld.io` (or `do.sommerfeld.io/fantasy-hockey`) serves the app with an automatically renewed certificate via Caddy, which replaces nginx; the app is published only on `127.0.0.1:8080`.

- **CAP-10**
    - **intent:** (E7) The droplet stays healthy without attention.
    - **success:** Unattended-upgrades, logrotate and disk cleanup, memory limits (compose `mem_limit`, Alloy `MemoryMax`) and a post-deploy smoke test of the public URL are in place; the Raspberry Pi deployment is decommissioned.

- **CAP-11**
    - **intent:** (E8) The data file survives loss of the volume through a backup the app knows nothing about.
    - **success:** A scheduled backup of `fantasy-hockey.yml` exists, and a fresh droplet restores it automatically right after the default file is seeded.

## Constraints

- Epic order is E1 droplet, E2 provisioning, E3 deploy, E4 dashboard, E5 GitHub Actions (a Must, fifth), E6 HTTPS, E7 hardening, E8 backup last. Everything runs locally via go-task before CI is built. Details in `epics.md`.
- `fantasy-hockey.yml` is seeded from the default template only when absent; when present it may be overwritten only from a backup, never from template contents.
- `DIGITALOCEAN_TOKEN` is the token env var. Locally it comes from `ansible/vars/vault.yml` via `ansible/tasks/bash-secrets.yml`, not from playbooks that target DigitalOcean. CI needs separate org-level GitHub secrets for the token and the vault password (OpenTofu runs before Ansible); all vaults share one password. The CI SSH keypair is fresh and its private key never leaves CI.
- Inventory is the DigitalOcean dynamic inventory plugin selecting by tag; no static IPs and no generated or committed inventory (a commit under `cloud-configs/digital-ocean` would retrigger the pipeline).
- Only the fantasy-hockey compose role moves out of `ansible/` (into `cloud-configs/digital-ocean/ansible/roles`); all other roles are reused through relative paths, not `roles_path`.
- The volume is formatted and mounted declaratively by OpenTofu (`initial_filesystem_type` ext4, attached at creation); no DO user-data scripts, no DO firewall, no managed DB, one droplet.
- `stage` is defined once and reused in the droplet tag, droplet name, inventory group and the Alloy label. `source` is already taken as a label, so the new label is `environment`.
- Budget is about $6 per month for the droplet plus about $0.20 for the volume; resize CPU and RAM only, never disk.
- Pin OpenTofu and provider versions. Containers use `restart: unless-stopped`, Alloy runs as a systemd service, cron handles regular jobs.
- Architecture rule AD-10 in the adopted `ARCHITECTURE-SPINE.md` governs this work: cloud deployments are a bounded context under `cloud-configs/` with carve-outs from AD-1, AD-4, AD-6, AD-8 and AD-9. The fleet rules stay unchanged outside it.
- All other platform decisions (droplet spec, naming, monitoring wiring) are in `platform-decisions.md`.

## Non-goals

- Scaling the production app, zero-downtime migration, in-place OS upgrades.
- Tailscale, Cloudflare, DO App Platform and DO Load Balancer.
- HTTPS or a custom domain before E6; backup and restore before E8; alerts (observe first).
- Building a second droplet (test stage or another app); the design only has to make it cheap later.

## Success signal

The app is reachable from the internet at a static address while nothing is exposed on the home network. A change merged under `cloud-configs/digital-ocean` reaches the droplet through the pipeline without manual steps, and the same flow runs from localhost. The droplet runs for months unattended, and a replacement droplet comes up from the repo alone.

## Assumptions

- Docs live at `docs/cloud/digital-ocean` (the source said `docscloud/digital-ocean`).
- "Shipped to digital ocean" in the monitoring requirement meant Grafana Cloud.
- `picon___id_rsa.pub` is the name of an SSH key already registered on DigitalOcean, alongside the key from the local `id_rsa.pub`.
- This spec is separate from `spec-configs-homelab`, which governs the existing fleet. Its non-goal on formal backup tooling is read as scoped to fleet nodes, so it does not block CAP-11.

## Open Questions

- Verify before E1/E2: the Ubuntu 26.04 image slug and Docker apt support, whether the declaratively attached volume auto-mounts under `/mnt/<name>` and persists across reboot, and the `community.digitalocean` inventory plugin options (tag filter, groups from tags, public IPv4, token from env).
- Which OpenTofu linter, and does the `raspi_` to `fantasy_hockey_` var rename pass ansible-lint?
- Which remote state backend with locking for E5 (DO Spaces is the candidate)?
- Do synthetic monitoring limits allow the new check, and how are the existing checks provisioned?
- Is 1 vCPU / 1 GB RAM enough for docker, nginx, the app and Alloy?
- Should unattended-upgrades move earlier than E7, given the unattended long-term requirement?
