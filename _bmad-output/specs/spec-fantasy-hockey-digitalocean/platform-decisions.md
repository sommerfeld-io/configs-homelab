# Platform decisions — Fantasy Hockey on DigitalOcean

## Droplet and resources

| Item            | Decision                                                                                  |
|-----------------|-------------------------------------------------------------------------------------------|
| Size            | `s-1vcpu-1gb` (basic shared CPU, about $6/month), quantity 1                              |
| Region          | `fra1`                                                                                    |
| Image           | Ubuntu 26.04 LTS x64                                                                      |
| Network         | Public IPv4, plus a reserved IP managed by OpenTofu                                       |
| Name and tag    | Name starts with `prod-fantasy-hockey`; tag `prod`                                        |
| Project         | `sommerfeld.io`, named explicitly                                                         |
| Monitoring      | DO improved metrics on                                                                    |
| Disabled        | DO user-data scripts, managed DB, DO firewall                                             |
| Volume          | 2 GB, ext4, `initial_filesystem_type`, attached at creation; mount `/mnt/<volume-name>`   |
| Data path       | `/mnt/<volume-name>/fantasy-hockey` (or whatever works best)                              |
| Protection      | `prevent_destroy` on volume and reserved IP (may change in E8)                            |
| SSH keys        | Existing DO key from local `id_rsa.pub` plus the key named `picon___id_rsa.pub`           |
| Resize          | One-line OpenTofu change; CPU/RAM only, never disk                                        |

## Secrets and access

| Secret                | Local                                      | CI (E5)                       |
|-----------------------|--------------------------------------------|-------------------------------|
| `DIGITALOCEAN_TOKEN`  | `vault.yml` through `bash-secrets.yml`     | Org-level GitHub secret       |
| Vault password        | Prompted manually                          | Org-level GitHub secret       |
| SSH private key       | Existing local key                         | Fresh CI-only keypair (secret) |
| Spaces keys           | Only if a Spaces state backend is chosen   | Same                          |

- Token scopes: droplet, ssh_key, volume, reserved IP, project; firewall or domain only if needed.
- The CI SSH public key is registered on DO in addition to the local key (E5 only).
- All GitHub secrets live at the organization level so other repos can deploy to DO without duplicates.

## Inventory and playbooks

- Dynamic inventory with the `community.digitalocean` plugin, selected by tag, needing only `DIGITALOCEAN_TOKEN`; groups `ubuntu` and `fantasy-hockey` are composed from tags.
- `provision.yml` targets `ubuntu`; `deploy-services.yml` targets `fantasy-hockey`.
- Bash prompt is the same as for the ubuntu server in `ansible/hosts.yml`, with `user@host` in yellow.

## Observability

- Alloy installed through `ansible/roles/grafana-cloud`, secrets from `ansible/vars/grafana-vault.yml`; scrapes the app at `:8080/metrics`, ships OS metrics and logs.
- Labels: `environment` (`homelab` or `digitalocean`) in both Alloy configs; `stage=prod` on the droplet.
- External availability through Grafana Cloud synthetic monitoring; no alerts yet.

## Exposure

- App listens on 8080, open to the internet; epic 1 serves plain HTTP via nginx on port 80 at the reserved IP.
- The app runs as docker compose on the droplet.

## Repo layout

- `cloud-configs/digital-ocean/opentofu` and `cloud-configs/digital-ocean/ansible` (own playbooks, roles, inventory config); `cloud-configs/taskfile.yml` included in the main taskfile with prefix `cloud`, DO tasks as `cloud:digital-ocean:*`.
- Docs in `docs/cloud/digital-ocean` with a `mkdocs.yml` nav item "Cloud - Digital Ocean".
- Dashboard in `grafana-cloud/manifests/git-sync/apps`.
