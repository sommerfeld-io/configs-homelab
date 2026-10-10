# Epics — Fantasy Hockey on DigitalOcean

Delivery order. Everything runs locally via go-task before CI (E5). Each epic includes its docs under `docs/cloud/digital-ocean`.

| Epic | Name                         | MoSCoW          | Capabilities |
|------|------------------------------|-----------------|--------------|
| E1   | Droplet via OpenTofu (local) | Must            | CAP-1, CAP-6 |
| E2   | Provisioning via Ansible     | Must            | CAP-2, CAP-4 |
| E3   | App deployment               | Must            | CAP-3, CAP-8 |
| E4   | Grafana dashboard            | Should          | CAP-4        |
| E5   | GitHub Actions               | Must            | CAP-5        |
| E6   | HTTPS, domain, Caddy         | Could           | CAP-9        |
| E7   | Operations hardening         | Could           | CAP-10       |
| E8   | Backup and restore           | Won't this time | CAP-11       |

CAP-7 (docs) applies to every epic.

## E1 Droplet via OpenTofu

- Droplet, tag, project, SSH keys, 2 GB volume (declarative ext4, auto-mount), reserved IP, `prevent_destroy` on volume and IP, local state, provider version pinning.
- `cloud-configs/taskfile.yml` included with prefix `cloud`; OpenTofu linter; folderslint and ls-lint updates.
- Devcontainer installs `doctl` and OpenTofu.
- `DIGITALOCEAN_TOKEN` delivered through `vault.yml` and `bash-secrets.yml`.
- Droplet defined as a module or `for_each` keyed by name and stage.

## E2 Provisioning via Ansible

- `provision.yml` against the dynamic inventory (groups `ubuntu` and `fantasy-hockey`).
- Bash config with the existing ubuntu-server prompt, `user@host` in yellow.
- Docker, swap file, Alloy via the existing `ansible/roles/grafana-cloud` role.
- Alloy labels `environment` and `stage`, also added to the homelab `config.alloy.j2` (`environment=homelab`).
- ansible-lint covers the new folder.

## E3 App deployment

- `deploy-services.yml` and the fantasy-hockey compose role moved from `ansible/roles/raspi/fantasy-hockey` into `cloud-configs/digital-ocean/ansible/roles` with `fantasy_hockey_` vars.
- nginx on port 80, data on the volume at `/mnt/<volume-name>/fantasy-hockey`, default-seed rule for `fantasy-hockey.yml`.
- Dependabot bumps of compose images.
- Droplet replacement keeps IP and data (CAP-8).

## E4 Grafana dashboard

- Comprehensive dashboard in `grafana-cloud/manifests/git-sync/apps`: CPU, memory and more, the app, containers, logs of all containers.
- Synthetic external check of the public URL (Should).
- No alerts.

## E5 GitHub Actions

- `cloud-deployment.yml` triggered by changes in `cloud-configs/digital-ocean`: static checks, OpenTofu, provisioning, deployment.
- Org-level secrets (DO token, vault password, CI SSH key), fresh CI SSH keypair registered on DO.
- Shared remote state with locking between localhost and Actions.

## E6 HTTPS, domain, Caddy

- Custom domain, Caddy with automatic TLS replacing nginx, app on `127.0.0.1:8080`.
- Fallback if no domain: `<ip>.sslip.io`.

## E7 Operations hardening

- Unattended-upgrades, logrotate and disk cleanup, memory limits, post-deploy smoke test, Raspberry Pi decommission, token expiry and Ubuntu EOL planning.

## E8 Backup and restore

- Infra concern, not app concern; scheduled backup (not after each edit), restore on a fresh droplet right after the default seed.
- Target candidates: DO Spaces, droplet snapshots, private git repo.
- Revisit `prevent_destroy`.
