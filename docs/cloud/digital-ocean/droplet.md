# Droplet

The production droplet for the fantasy hockey app, its reserved IP and its data volume are declared with OpenTofu in `configs-cloud/digital-ocean/opentofu/`. Nothing is clicked together in the DigitalOcean web console.

## Files

| File                  | Content                                                                                                          |
|-----------------------|------------------------------------------------------------------------------------------------------------------|
| `versions.tf`         | Pinned OpenTofu version and `digitalocean/digitalocean` provider, empty provider block                           |
| `droplets.tf`         | `stage`, region, droplet map, SSH key lookup and the `digitalocean_droplet` resource                             |
| `volumes.tf`          | One `digitalocean_volume` per droplet: ext4 data volume with `prevent_destroy`                                   |
| `reserved-ips.tf`     | One `digitalocean_reserved_ip` per droplet with `prevent_destroy`, and its `digitalocean_reserved_ip_assignment` |
| `project.tf`          | Lookup of the project `sommerfeld.io` and assignment of all droplets, volumes and reserved IPs to it             |
| `outputs.tf`          | `droplet_ipv4_addresses`, `reserved_ip_addresses` and `volume_mount_paths`, keyed by droplet name                |
| `.terraform.lock.hcl` | Provider lock file with hashes for every platform the provider is released for, committed                        |

The provider reads the API token from `DIGITALOCEAN_ACCESS_TOKEN`. The token is never written to a `.tf` or `.tfvars` file. See [API Token](api-token.md).

## Attributes

| Attribute  | Value                                     |
|------------|-------------------------------------------|
| Name       | `prod-fantasy-hockey`                     |
| Size       | `s-1vcpu-1gb` (1 vCPU, 1 GB RAM)          |
| Region     | `fra1`                                    |
| Image      | `ubuntu-26-04-x64` (Ubuntu 26.04 LTS x64) |
| Monitoring | DigitalOcean monitoring agent on          |
| Resize     | CPU and RAM only, the disk never grows    |
| Tags       | `prod`                                    |
| SSH keys   | `picon___id_rsa.pub`                      |
| Project    | `sommerfeld.io`                           |
| Volume     | `prod-fantasy-hockey-data`, 2 GB, ext4    |
| Address    | Reserved IP, see `reserved_ip_addresses`  |

There is no firewall, user-data script or backup yet.

## Reserved IP and Volume

Every droplet in the map gets one reserved IP and one data volume in the same region. Both are added to the project `sommerfeld.io`.

| Resource    | Name / Address                                           | Details                                                                                                   |
|-------------|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| Reserved IP | Assigned by DigitalOcean, output `reserved_ip_addresses` | Stable public IPv4 address, assigned to the droplet with a separate `digitalocean_reserved_ip_assignment` |
| Volume      | `<droplet-name>-data`, e.g. `prod-fantasy-hockey-data`   | `volume_size_gb` GB (2 GB) ext4, attached at creation through the droplet's `volume_ids`                  |

`initial_filesystem_type` formats the volume with ext4 when the volume is created. Because the droplet attaches it at creation, DigitalOcean also mounts it automatically under `/mnt/<volume-name>`, with the hyphens in the name turned into underscores: `/mnt/prod_fantasy_hockey_data`. The output `volume_mount_paths` prints this path. Check the real mount on the droplet with `ssh root@<reserved-ip> 'df -hT | grep /mnt'`. Ansible manages the mount from Epic 3 on.

Both the volume and the reserved IP have `lifecycle { prevent_destroy = true }`. OpenTofu refuses every plan that would destroy them, including `tofu plan -destroy`, with the error `Resource instance cannot be destroyed`. The droplet and the IP assignment have no `prevent_destroy`, so the droplet stays replaceable.

When the droplet is replaced, OpenTofu destroys only the old droplet. The new droplet gets the same volume through `volume_ids`, and the assignment is recreated so the reserved IP points to the new droplet. The data on the volume and the public address survive; only the droplet's own public IPv4 changes. Always connect through the reserved IP. The new droplet answers on the reserved IP with a new SSH host key, so remove the old one with `ssh-keygen -R <reserved-ip>` before connecting.

There is no resizing logic for the volume. Raising `volume_size_gb` grows the block device in place, but the ext4 filesystem only uses the new space after `resize2fs` runs on the droplet. Lowering `volume_size_gb` fails, because a volume can never shrink.

To remove a map entry or retire a volume or reserved IP, `prevent_destroy` makes the plan fail with `Resource instance cannot be destroyed`. The intended way out is a reviewed commit that removes the `lifecycle` block from the resource first, or `tofu state rm` followed by manual cleanup in DigitalOcean. A reserved IP that is left over and unassigned is billed.

Cost: the 2 GB volume costs about $0.20 per month. A reserved IP is free while it is assigned to a droplet; an unassigned reserved IP is billed.

## Stage and Droplet Map

`droplets.tf` defines the stage once in `locals`. It builds both the name prefix and the tag, so every droplet is called `<stage>-<key>` and tagged `<stage>`:

```hcl
locals {
  stage  = "prod"
  region = "fra1"

  droplets = {
    fantasy-hockey = {
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      volume_size_gb = 2
    }
  }
}
```

The `digitalocean_droplet.this`, `digitalocean_volume.this`, `digitalocean_reserved_ip.this` and `digitalocean_reserved_ip_assignment.this` resources iterate over `local.droplets` with `for_each`. `project.tf` assigns every droplet, volume and reserved IP to the project `sommerfeld.io`, and `outputs.tf` prints the addresses and mount paths of every droplet in the map.

## Add a Droplet

Add one entry to the `droplets` map. Nothing else changes:

```hcl
  droplets = {
    fantasy-hockey = {
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      volume_size_gb = 2
    }
    example-app = {
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      volume_size_gb = 2
    }
  }
```

This creates `prod-example-app` with the tag `prod`, its reserved IP and the volume `prod-example-app-data` in the same region and project. Do not repeat the stage in the map key.

## SSH Keys

The SSH keys already exist on the DigitalOcean account and are not owned by this configuration. OpenTofu looks them up by name with the `digitalocean_ssh_key` data source, so `tofu destroy` can never delete them and no local public key file is needed in the devcontainer. The names are listed in `local.ssh_key_names` in `droplets.tf`.

Only `picon___id_rsa.pub` is injected. It is the same key as the operator workstation's `id_rsa.pub`. The second key in the planning documents is a dedicated CI keypair that is added together with the GitHub Actions epic.

If a key name is not registered on DigitalOcean, `plan` fails on the data source and the provider error names the missing key.

DigitalOcean only injects SSH keys when a droplet is created, and OpenTofu is the only place that injects them. Changing the key list or the image later replaces only the droplet, and the replacement gets a new public IPv4 address of its own. The reserved IP and the volume keep the stable address and the data across that replacement, see [Reserved IP and Volume](#reserved-ip-and-volume).

Changing the region, renaming `stage` or renaming a map key is different: the region forces a new volume and reserved IP, and the names rename the volume (which forces a new one). `prevent_destroy` refuses that plan, so such a change needs a deliberate migration.

## Apply

Run the steps from the repository root with `DIGITALOCEAN_ACCESS_TOKEN` set:

1. `task cloud:digital-ocean:opentofu:init`: download the pinned provider, verified against the committed lock file.
2. `task cloud:digital-ocean:opentofu:plan`: on an empty state the plan shows `5 to add` (the volume, the droplet, the reserved IP, its assignment and the project assignment), `0 to change`, `0 to destroy`.
3. `task cloud:digital-ocean:opentofu:apply`: review the plan again and confirm with `yes`. The output prints the droplet's own public IPv4 address, the reserved IP and the volume mount path.
4. `task cloud:digital-ocean:opentofu:plan`: a second plan must print `No changes.`

For the record: `prod-fantasy-hockey` existed before the volume was added. DigitalOcean only mounts a volume automatically when it is attached at droplet creation, so the empty droplet was replaced once on 2026-10-12, when the volume was added. This was a one-time migration that already ran; do not repeat it. New droplets get their volume attached at creation by the normal apply above.

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu apply -replace='digitalocean_droplet.this["fantasy-hockey"]'
```

The plan showed `4 to add, 1 to change, 1 to destroy`: only the old droplet was destroyed, the volume and the reserved IP were created. There is no task for this step.

Check the result with `doctl`:

```bash
doctl compute droplet get prod-fantasy-hockey --format Name,SizeSlug,Region,Image,Tags,Features
doctl compute reserved-ip list --format IP,Region,DropletName
doctl compute volume list --format Name,Size,Region,DropletIDs
doctl projects list --format ID,Name
doctl projects resources list <project-id>
```

If the DigitalOcean commands fail inside the devcontainer, the usual cause is an empty `DIGITALOCEAN_ACCESS_TOKEN` in the container, see [Verify](api-token.md#verify). As a fallback, run them on the host.
