# Droplet

The production droplet for the fantasy hockey app is declared with OpenTofu in `cloud-configs/digital-ocean/opentofu/`. Nothing is clicked together in the DigitalOcean web console.

## Files

| File                  | Content                                                                                     |
|-----------------------|---------------------------------------------------------------------------------------------|
| `versions.tf`         | Pinned OpenTofu version and `digitalocean/digitalocean` provider, empty provider block      |
| `droplets.tf`         | `stage`, region, droplet map, SSH key lookup and the `digitalocean_droplet` resource        |
| `project.tf`          | Lookup of the project `sommerfeld.io` and assignment of all droplets to it                  |
| `outputs.tf`          | `droplet_ipv4_addresses`: public IPv4 address of each droplet, keyed by droplet name        |
| `.terraform.lock.hcl` | Provider lock file with hashes for every platform the provider is released for, committed   |

The provider reads the API token from `DIGITALOCEAN_ACCESS_TOKEN`. The token is never written to a `.tf` or `.tfvars` file. See [API Token](api-token.md).

## Attributes

| Attribute  | Value                                     |
|------------|-------------------------------------------|
| Name       | `prod-fantasy-hockey`                     |
| Size       | `s-1vcpu-1gb` (1 vCPU, 1 GB RAM)          |
| Region     | `fra1`                                    |
| Image      | `ubuntu-26-04-x64` (Ubuntu 26.04 LTS x64) |
| Monitoring | DigitalOcean monitoring agent on          |
| Tags       | `prod`                                    |
| SSH keys   | `picon___id_rsa.pub`                      |
| Project    | `sommerfeld.io`                           |

There is no reserved IP, volume, firewall, user-data script or backup yet. The reserved IP and the volume follow in a later story.

## Stage and Droplet Map

`droplets.tf` defines the stage once in `locals`. It builds both the name prefix and the tag, so every droplet is called `<stage>-<key>` and tagged `<stage>`:

```hcl
locals {
  stage  = "prod"
  region = "fra1"

  droplets = {
    fantasy-hockey = {
      size  = "s-1vcpu-1gb"
      image = "ubuntu-26-04-x64"
    }
  }
}
```

The `digitalocean_droplet.this` resource iterates over `local.droplets` with `for_each`. `project.tf` assigns every droplet in the map to the project `sommerfeld.io`, and `outputs.tf` prints the address of every droplet in the map.

## Add a Droplet

Add one entry to the `droplets` map. Nothing else changes:

```hcl
  droplets = {
    fantasy-hockey = {
      size  = "s-1vcpu-1gb"
      image = "ubuntu-26-04-x64"
    }
    example-app = {
      size  = "s-1vcpu-1gb"
      image = "ubuntu-26-04-x64"
    }
  }
```

This creates `prod-example-app` with the tag `prod` in the same region and project. Do not repeat the stage in the map key.

## SSH Keys

The SSH keys already exist on the DigitalOcean account and are not owned by this configuration. OpenTofu looks them up by name with the `digitalocean_ssh_key` data source, so `tofu destroy` can never delete them and no local public key file is needed in the devcontainer. The names are listed in `local.ssh_key_names` in `droplets.tf`.

Only `picon___id_rsa.pub` is injected. It is the same key as the operator workstation's `id_rsa.pub`. The second key in the planning documents is a dedicated CI keypair that is added together with the GitHub Actions epic.

If a key name is not registered on DigitalOcean, `plan` fails on the data source and the provider error names the missing key.

DigitalOcean only injects SSH keys when a droplet is created, and OpenTofu is the only place that injects them. Changing the key list, the image or the region later replaces the droplet, and the replacement gets a new public IPv4 address. Once the reserved IP and the volume are added in a later story, they keep the address and the data across a replacement.

## Apply

Run the steps from the repository root with `DIGITALOCEAN_ACCESS_TOKEN` set:

1. `task cloud:digital-ocean:opentofu:init`: download the pinned provider, verified against the committed lock file.
2. `task cloud:digital-ocean:opentofu:plan`: on an empty state the plan shows `2 to add` (the droplet and the project assignment), `0 to change`, `0 to destroy`.
3. `task cloud:digital-ocean:opentofu:apply`: review the plan again and confirm with `yes`. The output prints the public IPv4 address of the droplet.
4. `task cloud:digital-ocean:opentofu:plan`: a second plan must print `No changes.`

Check the result with `doctl`:

```bash
doctl compute droplet get prod-fantasy-hockey --format Name,SizeSlug,Region,Image,Tags,Features
doctl projects list --format ID,Name
doctl projects resources list <project-id>
```

If the DigitalOcean commands fail inside the devcontainer, the usual cause is an empty `DIGITALOCEAN_ACCESS_TOKEN` in the container, see [Verify](api-token.md#verify). As a fallback, run them on the host.
