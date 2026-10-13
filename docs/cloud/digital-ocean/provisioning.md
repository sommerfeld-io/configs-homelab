# Provisioning

Droplets are configured with Ansible from `configs-cloud/digital-ocean/ansible`. No host is listed anywhere: the inventory asks the DigitalOcean API for the droplets, so a new or replaced droplet is found again without editing a file.

## Dynamic Inventory

`inventory/digitalocean.yml` configures the `community.digitalocean.digitalocean` inventory plugin:

- The token is passed explicitly as `oauth_token` from `lookup('env', 'DIGITALOCEAN_ACCESS_TOKEN')`. See [API Token](api-token.md).
- A filter keeps only droplets tagged `prod` (the stage tag from OpenTofu).
- `tags` is part of the plugin `attributes`, so groups can be composed from them.
- Each droplet is addressed by its own public IPv4, not by the reserved IP.
- `compose` sets `ansible_user` to `root` (the only user on a droplet) and `StrictHostKeyChecking=accept-new`, so the first connection to a new droplet does not prompt for its host key. A changed host key is still refused, see below.

| Group            | Members                                                  |
|------------------|----------------------------------------------------------|
| `ubuntu`         | All selected droplets whose image distribution is Ubuntu |
| `fantasy-hockey` | All selected droplets with the tag `fantasy-hockey`      |

The tag `fantasy-hockey` is set through the optional `tags` list of the droplet map, see [Droplet](droplet.md). The collection `community.digitalocean` is a pinned third-party dependency in `ansible/requirements.yml`; the tasks install it before Ansible runs.

## provision.yml

`playbooks/provision.yml` targets the generic group `ubuntu` and connects as `root`. It reuses roles from `configs-homelab/ansible/roles` through relative paths:

- `docker`: Docker from the Docker apt repository.
- `bash` (only `11-bash-config-root`): aliases and the root prompt `ps1_root` in `/root/.bashrc`. The prompt is the root prompt of the local ubuntu machines, defined in `ansible/vars/main.yml`.

The playbook is idempotent: a second run reports `changed=0`.

## Tasks

```bash
task cloud:digital-ocean:ansible:inventory   # droplets and their groups
task cloud:digital-ocean:ansible:provision   # run provision.yml
task cloud:digital-ocean:deploy              # full pipeline: opentofu:apply, then ansible:provision
```

All three stop early when `DIGITALOCEAN_ACCESS_TOKEN` is not set.

## Replaced Droplet and Host Key

A replaced droplet has the same tags but a new public IP and a new SSH host key. The inventory finds it again. If SSH reports a changed host key, remove the old entry first:

```bash
ssh-keygen -R <old-droplet-ip>
```
