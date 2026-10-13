# Droplet

Droplets, and optionally a reserved IP and a data volume for each of them, are declared with OpenTofu in `configs-cloud/digital-ocean/opentofu/`. Nothing is clicked together in the DigitalOcean web console.

All droplets come from one map, `local.droplets`. Each entry chooses its own size, image, resize behavior, reserved IP and data volume, so the same configuration serves very different workloads.

## Files

| File                  | Content                                                                                                            |
|-----------------------|--------------------------------------------------------------------------------------------------------------------|
| `versions.tf`         | Pinned OpenTofu version and `digitalocean/digitalocean` provider, empty provider block                             |
| `droplets.tf`         | region, droplet map, SSH key lookup and the `digitalocean_droplet` resource                                        |
| `volumes.tf`          | A `digitalocean_volume` for each droplet with a `volume_size_gb`: ext4 data volume with `prevent_destroy`          |
| `reserved-ips.tf`     | A `digitalocean_reserved_ip` for each droplet with `reserved_ip = true` and `prevent_destroy`, plus its assignment |
| `project.tf`          | Lookup of the project `sommerfeld.io` and assignment of all droplets, volumes and reserved IPs to it               |
| `outputs.tf`          | `droplet_ipv4_addresses`, `reserved_ip_addresses` and `volume_mount_paths`, keyed by droplet name                  |
| `.terraform.lock.hcl` | Provider lock file with hashes for every platform the provider is released for, committed                          |

The provider reads the API token from `DIGITALOCEAN_ACCESS_TOKEN`. The token is never written to a `.tf` or `.tfvars` file. See [API Token](api-token.md).

## Region

`droplets.tf` defines the region once in `locals`. It applies to all droplets, volumes and reserved IPs.

| Setting  | Current value | Effect                                          |
|----------|---------------|-------------------------------------------------|
| `region` | `fra1`        | Region of every droplet, volume and reserved IP |

## Droplet Config Options

Each entry of the `droplets` map describes one droplet. The `stage` and the map key build the droplet name `<stage>-<key>`, so the stage `prod` and the key `example-app` create the droplet `prod-example-app`. Do not repeat the stage in the key. All options are required except `tags`.

| Option           | Allowed values          | Effect                                                                                                                                                                         |
|------------------|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `stage`          | `dev`, `test` or `prod` | Name prefix and tag of the droplet. The volume name uses it as well                                                                                                            |
| `size`           | DigitalOcean size slug  | CPU and RAM of the droplet, e.g. `s-1vcpu-1gb`                                                                                                                                 |
| `image`          | DigitalOcean image slug | Operating system the droplet is created from, e.g. `ubuntu-26-04-x64`                                                                                                          |
| `resize_disk`    | `true` or `false`       | Whether a resize also grows the disk. `false` resizes CPU and RAM only                                                                                                         |
| `reserved_ip`    | `true` or `false`       | `true` gives the droplet a stable public address. `false` means no reserved IP                                                                                                 |
| `volume_size_gb` | Number of GB, or `null` | A number creates and attaches a data volume of that size. `null` means no block volume                                                                                         |
| `tags`           | Optional list of labels | Extra droplet tags next to the stage tag, e.g. `["fantasy-hockey"]`. Ansible [composes inventory groups](provisioning.md) from them. Adding a tag updates the droplet in place |

An annotated example with two different droplets:

```hcl
locals {
  region = "fra1"

  droplets = {
    # Stateful workload: stable address and persistent data volume.
    example-app = {
      stage          = "prod"
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      reserved_ip    = true
      volume_size_gb = 2
    }
    # Throwaway workload: no reserved IP and no volume.
    example-scratch = {
      stage          = "test"
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      reserved_ip    = false
      volume_size_gb = null
    }
  }
}
```

The `digitalocean_droplet.this` resource iterates over `local.droplets` with `for_each`. `local.droplets_with_reserved_ip` and `local.droplets_with_volume` are filtered views of the same map. The reserved IP, the reserved IP assignment and the volume resources iterate over those views, so a droplet only gets what its options ask for. `project.tf` assigns every droplet, volume and reserved IP that exists to the project `sommerfeld.io`, and `outputs.tf` prints addresses and mount paths for the droplets that have them.

### stage

The stage labels the environment of a droplet. It becomes the name prefix and the tag, so `stage = "test"` with the key `example-scratch` creates `test-example-scratch` tagged `test`. The volume of that droplet is called `test-example-scratch-data`. Different droplets can have different stages. The stages are `dev`, `test` and `prod`; Ansible makes one inventory group per stage, see [Provisioning](provisioning.md).

### size and image

`size` and `image` are passed to DigitalOcean unchanged. Look up valid slugs with `doctl compute size list` and `doctl compute image list-distribution`. Changing `image` replaces the droplet. Changing `size` resizes it in place.

### resize_disk

With `resize_disk = false` a resize only changes CPU and RAM. A grown disk can never shrink again, so a later downsize would be impossible without replacing the droplet. Use `true` only when the extra disk is wanted for good, because the change is irreversible.

### reserved_ip

With `reserved_ip = true` the droplet gets a reserved IP in the same region. See [Reserved IP and Volume](#reserved-ip-and-volume). With `false` the droplet is reachable only on its own public IPv4 address, which changes whenever the droplet is replaced.

### volume_size_gb

A number creates a data volume named `<droplet-name>-data` and attaches it at creation. `null` skips the volume, and the droplet is created without any attached block storage.

## Attributes Shared by All Droplets

These settings are not options of their own. They are fixed or derived from the options above for every entry in the map.

| Attribute  | Value                                                |
|------------|------------------------------------------------------|
| Name       | `<stage>-<key>`                                      |
| Region     | `local.region`                                       |
| Monitoring | DigitalOcean monitoring agent on                     |
| Tags       | The droplet's `stage`, plus its optional `tags` list |
| SSH keys   | All keys in `local.ssh_key_names`                    |
| Project    | `sommerfeld.io`                                      |

There is no firewall, user-data script or backup yet.

## Reserved IP and Volume

A droplet gets a reserved IP when its `reserved_ip` is `true` and a data volume when its `volume_size_gb` is a number. Both live in the same region as the droplet and are added to the project `sommerfeld.io`.

| Resource    | Name / Address                                           | Details                                                                                                   |
|-------------|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| Reserved IP | Assigned by DigitalOcean, output `reserved_ip_addresses` | Stable public IPv4 address, assigned to the droplet with a separate `digitalocean_reserved_ip_assignment` |
| Volume      | `<droplet-name>-data`, e.g. `prod-example-app-data`      | `volume_size_gb` GB ext4, attached at creation through the droplet's `volume_ids`                         |

`initial_filesystem_type` formats the volume with ext4 when the volume is created. Because the droplet attaches it at creation, DigitalOcean also mounts it automatically under `/mnt/<volume-name>`, with the hyphens in the name turned into underscores: `/mnt/prod_example_app_data`. The output `volume_mount_paths` prints this path. Check the real mount on the droplet with `ssh root@<reserved-ip> 'df -hT | grep /mnt'`. Ansible manages the mount from Epic 3 on.

Both the volume and the reserved IP have `lifecycle { prevent_destroy = true }`. OpenTofu refuses every plan that would destroy them, including `tofu plan -destroy`, with the error `Resource instance cannot be destroyed`. The droplet and the IP assignment have no `prevent_destroy`, so the droplet stays replaceable.

When a droplet that has them is replaced, OpenTofu destroys only the old droplet. The new droplet gets the same volume through `volume_ids`, and the assignment is recreated so the reserved IP points to the new droplet. The data on the volume and the public address survive; only the droplet's own public IPv4 changes. Always connect through the reserved IP. The new droplet answers on the reserved IP with a new SSH host key, so remove the old one with `ssh-keygen -R <reserved-ip>` before connecting.

There is no resizing logic for the volume. Raising `volume_size_gb` grows the block device in place, but the ext4 filesystem only uses the new space after `resize2fs` runs on the droplet. Lowering `volume_size_gb` fails, because a volume can never shrink.

Switching `reserved_ip` to `false` or `volume_size_gb` to `null` on an existing droplet, and removing a map entry, all plan the destruction of those resources. `prevent_destroy` makes the plan fail with `Resource instance cannot be destroyed`. The intended way out is a reviewed commit that removes the `lifecycle` block from the resource first, or `tofu state rm` followed by manual cleanup in DigitalOcean. A reserved IP that is left over and unassigned is billed.

Cost: a volume costs about $0.10 per GB and month. A reserved IP is free while it is assigned to a droplet; an unassigned reserved IP is billed.

## Add a Droplet

Add one entry to the `droplets` map. Nothing else changes:

```hcl
    example-app = {
      stage          = "prod"
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      reserved_ip    = true
      volume_size_gb = 2
    }
```

This creates `prod-example-app` with the tag `prod`, its reserved IP and the volume `prod-example-app-data` in the same region and project. Set `reserved_ip = false` and `volume_size_gb = null` for a droplet that needs neither.

## SSH Keys

The SSH keys already exist on the DigitalOcean account and are not owned by this configuration. OpenTofu looks them up by name with the `digitalocean_ssh_key` data source, so `tofu destroy` can never delete them and no local public key file is needed in the devcontainer. The names are listed in `local.ssh_key_names` in `droplets.tf`.

Only `picon___id_rsa.pub` is injected. It is the same key as the operator workstation's `id_rsa.pub`. The second key in the planning documents is a dedicated CI keypair that is added together with the GitHub Actions epic.

If a key name is not registered on DigitalOcean, `plan` fails on the data source and the provider error names the missing key.

DigitalOcean only injects SSH keys when a droplet is created, and OpenTofu is the only place that injects them. Changing the key list or the image later replaces only the droplet, and the replacement gets a new public IPv4 address of its own. A reserved IP and a volume keep the stable address and the data across that replacement, see [Reserved IP and Volume](#reserved-ip-and-volume).

Changing the region, changing a droplet's `stage` or renaming a map key is different: the region forces a new volume and reserved IP, and the names rename the volume (which forces a new one). `prevent_destroy` refuses that plan for droplets that have them, so such a change needs a deliberate migration.

## Apply

Run the steps from the repository root with `DIGITALOCEAN_ACCESS_TOKEN` set:

1. `task cloud:digital-ocean:opentofu:init`: download the pinned provider, verified against the committed lock file.
2. `task cloud:digital-ocean:opentofu:plan`: review what is added, changed and destroyed. Each new droplet adds the droplet itself, plus a volume, a reserved IP and its assignment if the options ask for them. The project assignment is updated as well.
3. `task cloud:digital-ocean:opentofu:apply`: review the plan again and confirm with `yes`. The output prints each droplet's own public IPv4 address, the reserved IPs and the volume mount paths.
4. `task cloud:digital-ocean:opentofu:plan`: a second plan must print `No changes.`

A droplet only gets its volume mounted automatically when the volume is attached at droplet creation. Adding `volume_size_gb` to an existing droplet therefore needs a one-time replacement of that droplet. Force it with `-replace`; there is no task for this step:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu apply -replace='digitalocean_droplet.this["<key>"]'
```

Check the result with `doctl`:

```bash
doctl compute droplet get <stage>-<key> --format Name,SizeSlug,Region,Image,Tags,Features
doctl compute reserved-ip list --format IP,Region,DropletName
doctl compute volume list --format Name,Size,Region,DropletIDs
doctl projects list --format ID,Name
doctl projects resources list <project-id>
```

If the DigitalOcean commands fail inside the devcontainer, the usual cause is an empty `DIGITALOCEAN_ACCESS_TOKEN` in the container, see [Verify](api-token.md#verify). As a fallback, run them on the host.
