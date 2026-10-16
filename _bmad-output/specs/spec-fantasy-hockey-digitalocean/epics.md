# Epics — Fantasy Hockey on DigitalOcean

Delivery order. Everything runs locally via go-task before CI (E5). Each epic includes its docs under `docs/cloud/digital-ocean`.

| Epic | Name                         | MoSCoW          | Capabilities |
|------|------------------------------|-----------------|--------------|
| E1   | Droplet via OpenTofu (local) | Must            | CAP-1, CAP-6 |
| E2   | Provisioning via Ansible     | Must            | CAP-2, CAP-4 |
| E3   | App deployment               | Must            | CAP-3, CAP-8 |
| E4   | Grafana dashboard            | Should          | CAP-4        |
| E6   | HTTPS, domain, Caddy         | Should          | CAP-9        |
| E5   | GitHub Actions               | Must            | CAP-5        |
| E7   | Operations hardening         | Could           | CAP-10       |
| E8   | Backup and restore           | Won't this time | CAP-11       |

E6 runs between the E4 dashboard and the E4 synthetic check (re-prioritized 2026-10-15), so the check probes the domain.

CAP-7 (docs) applies to every epic.

## E1 Droplet via OpenTofu

- Droplet, tag, project, SSH keys, 2 GB volume (declarative ext4, auto-mount), reserved IP, `prevent_destroy` on volume and IP, local state, provider version pinning.
- `configs-cloud/taskfile.yml` included with prefix `cloud`; OpenTofu linter; folderslint and ls-lint updates.
- Devcontainer installs `doctl` and OpenTofu.
- `DIGITALOCEAN_ACCESS_TOKEN` delivered from the vault key `DIGITALOCEAN_TOKEN` through `vault.yml` and `bash-secrets.yml`.
- Droplet defined as a module or `for_each` keyed by name and stage.

## E2 Provisioning via Ansible

- `provision.yml` against the dynamic inventory (groups `ubuntu` and `fantasy-hockey`).
- Bash config with the root prompt of the local ubuntu machines.
- Docker, swap file, Alloy via the existing `configs-homelab/ansible/roles/grafana-cloud` role.
- Alloy labels `environment` and `stage`, also added to the homelab `config.alloy.j2` (`environment=homelab`).
- ansible-lint covers the new folder.
- Login banner (MOTD): blank line, ASCII art "DigitalOcean", blank line, a live OS line, blank line, the live update info, blank line; all other default MOTD sections suppressed.

## E3 App deployment

- `deploy-fantasy-hockey.yml` and the fantasy-hockey compose role moved from `configs-homelab/ansible/roles/raspi/fantasy-hockey` into `configs-cloud/digital-ocean/ansible/roles` with `fantasy_hockey_` vars.
- nginx on port 80, data on the volume at `/mnt/prod_fantasy_hockey_data/fantasy-hockey`, default-seed rule for `fantasy-hockey.yml`.
- `deploy-fantasy-hockey.yml` targets the `fantasy-hockey` group and provisions a user `fantasy-hockey` (bash config from Ansible, member of the `docker` group), and runs the app with that user, not with root. This is not part of `provision.yml`.
- Dependabot bumps of compose images; the Dependabot entry moves with the role.
- Cleanup of the old Pi deployment: remove the role from `raspi.yml` (the pi4-0002 play is replaced by a cleanup play), move the `vault:fantasy-hockey` taskfile entry into the cloud taskfile, remove `/opt/fantasy-hockey` and stop and remove the containers on the Pi.
- Droplet replacement keeps IP and data (CAP-8).

## E4 Grafana dashboard

- Comprehensive dashboard in `grafana-cloud/manifests/git-sync/apps`: CPU, memory and more, the app, containers, logs of all containers.
- Synthetic external check of the public URL (Should).
- Caddy access, operational and certificate logs and the certificate's validity on the same dashboard (added 2026-10-15, after E6 brought Caddy).
- No alert rules on the dashboard; the synthetic check brings its three built-in alerts, not routed to a contact point yet.

## E5 GitHub Actions

- `cloud-deployment.yml` triggered by changes in `configs-cloud/digital-ocean`: static checks, OpenTofu, provisioning, deployment.
- Org-level secrets (DO token, vault password, CI SSH key), fresh CI SSH keypair registered on DO.
- Shared remote state with locking between localhost and Actions.

## E6 HTTPS, domain, Caddy

- Domain `fantasy-hockey.prod.do.sommerfeld.app` (pattern `<app>.<stage>.do.sommerfeld.app`): A record to the reserved IP, created by hand at all-inkl.com and documented.
- Caddy with automatic TLS replaces nginx and serves only that domain; the app stays on `127.0.0.1:8080`; certificates on the volume.

## E7 Operations hardening

- Unattended-upgrades, logrotate and disk cleanup, memory limits, post-deploy smoke test, remaining Raspberry Pi decommission (the app cleanup is in E3), token expiry and Ubuntu EOL planning.

## E8 Backup and restore

- Infra concern, not app concern; scheduled backup (not after each edit), restore on a fresh droplet right after the default seed.
- Target candidates: DO Spaces, droplet snapshots, private git repo.
- Revisit `prevent_destroy`.
