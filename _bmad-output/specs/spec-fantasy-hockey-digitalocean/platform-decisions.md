# Platform decisions — Fantasy Hockey on DigitalOcean

## Droplet and resources

| Item         | Decision                                                                                                                             |
|--------------|--------------------------------------------------------------------------------------------------------------------------------------|
| Size         | `s-1vcpu-1gb` (basic shared CPU, about $6/month), quantity 1                                                                         |
| Region       | `fra1`                                                                                                                               |
| Image        | Ubuntu 26.04 LTS x64                                                                                                                 |
| Network      | Public IPv4, plus a reserved IP managed by OpenTofu                                                                                  |
| Name and tag | Name `prod-fantasy-hockey` (`<stage>-<key>`); tag `prod`                                                                             |
| Project      | `sommerfeld.io`, named explicitly                                                                                                    |
| Monitoring   | DO improved metrics on                                                                                                               |
| Disabled     | DO user-data scripts, managed DB, DO firewall                                                                                        |
| Volume       | 2 GB, ext4, `initial_filesystem_type`, attached at creation; mounted at `/mnt/prod_fantasy_hockey_data` (hyphens become underscores) |
| Data path    | `/mnt/prod_fantasy_hockey_data/fantasy-hockey`                                                                                       |
| Protection   | `prevent_destroy` on volume and reserved IP (may change in E8)                                                                       |
| SSH keys     | `picon___id_rsa.pub` (the same key as the local `id_rsa.pub`); the CI key is added in E5                                             |
| Resize       | One-line OpenTofu change; CPU/RAM only, never disk                                                                                   |

## Secrets and access

| Secret             | Local                                                                                                             | CI (E5)                        |
|--------------------|-------------------------------------------------------------------------------------------------------------------|--------------------------------|
| DigitalOcean token | vault key `DIGITALOCEAN_TOKEN` in `vault.yml`, exported as `DIGITALOCEAN_ACCESS_TOKEN` through `bash-secrets.yml` | Org-level GitHub secret        |
| Vault password     | Prompted manually                                                                                                 | Org-level GitHub secret        |
| SSH private key    | Existing local key                                                                                                | Fresh CI-only keypair (secret) |
| Spaces keys        | Only if a Spaces state backend is chosen                                                                          | Same                           |

- Token scopes: droplet, ssh_key, block_storage, reserved_ip, project, actions (as documented in `docs/cloud/digital-ocean/api-token.md`); firewall or domain only if needed.
- The CI SSH public key is registered on DO in addition to the local key (E5 only).
- All GitHub secrets live at the organization level so other repos can deploy to DO without duplicates.

## Inventory and playbooks

- Dynamic inventory with the `community.digitalocean` plugin, selected by tag, authenticated with `DIGITALOCEAN_ACCESS_TOKEN` passed explicitly as the plugin's `oauth_token` from an env lookup, instead of relying on the plugin's default env vars (add `tags` to its `attributes`); groups `ubuntu` and `fantasy-hockey` are composed from tags.
- `provision.yml` targets `ubuntu`; `deploy-fantasy-hockey.yml` targets `fantasy-hockey`.
- `deploy-fantasy-hockey.yml` creates the user `fantasy-hockey` (bash config from Ansible, member of the `docker` group) and runs the app as that user, not as root. `provision.yml` stays root-only and does not create it.
- Root bash prompt is the root prompt (`ps1_root`) of the local ubuntu machines in `configs-homelab/ansible/hosts.yml`.

## Observability

- Alloy installed through `configs-homelab/ansible/roles/grafana-cloud`, secrets from `configs-homelab/ansible/vars/grafana-vault.yml`; scrapes the app at `:8080/metrics`, ships OS metrics and logs.
- Labels: `environment` (`homelab` or `digital-ocean`) in both Alloy configs; `stage=prod` on the droplet only (the homelab has no `stage` label).
- External availability through Grafana Cloud synthetic monitoring; no alerts yet.

## Exposure

- App listens on 8080, open to the internet; epic 1 serves plain HTTP via nginx on port 80 at the reserved IP.
- The app runs as docker compose on the droplet.

## Repo layout

- `configs-cloud/digital-ocean/opentofu` and `configs-cloud/digital-ocean/ansible` (own playbooks, roles, inventory config); `configs-cloud/taskfile.yml` included in the main taskfile with prefix `cloud`, DO tasks as `cloud:digital-ocean:*`.
- Docs in `docs/cloud/digital-ocean` with a `mkdocs.yml` nav item "Cloud - Digital Ocean".
- Dashboard in `grafana-cloud/manifests/git-sync/apps`.
