locals {
  region = "fra1"

  # The only stages allowed (docs/cloud/domain-naming.md). The stage is the
  # second label of the app's domain <app>.<stage>.do.sommerfeld.app.
  stages = ["dev", "test", "prod"]

  # One entry per droplet. The droplet name is "<stage>-<key>".
  #
  # Options (all required):
  #   stage          Label of the droplet: "dev", "test" or "prod"
  #                  (local.stages). Any other value fails the plan.
  #                  Builds the name prefix and the tag. Do not repeat it in
  #                  the key.
  #   size           DigitalOcean droplet size slug, e.g. "s-1vcpu-1gb".
  #   image          DigitalOcean image slug, e.g. "ubuntu-26-04-x64".
  #   resize_disk    true or false.
  #                  false resizes CPU and RAM only. A grown disk can never
  #                  shrink again, so a later downsize would be impossible
  #                  without replacing the droplet.
  #                  true also grows the disk on resize (irreversible).
  #   reserved_ip    true or false.
  #                  true gives the droplet a stable public address that
  #                  survives replacements.
  #   volume_size_gb Number (GB) or null.
  #                  A number creates and attaches a data volume of that size.
  #                  null means no block volume.
  #
  # Options (optional):
  #   tags           List of extra droplet tags, e.g. ["fantasy-hockey"].
  #                  Merged with the stage tag. Ansible composes inventory
  #                  groups from these tags. Defaults to no extra tags.
  droplets = {
    fantasy-hockey = {
      stage          = "prod"
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      reserved_ip    = true
      volume_size_gb = 2
      tags           = ["fantasy-hockey"]
    }
    # dummy = {
    #   stage          = "test"
    #   size           = "s-1vcpu-1gb"
    #   image          = "ubuntu-26-04-x64"
    #   resize_disk    = false
    #   reserved_ip    = false
    #   volume_size_gb = null
    # }
  }

  # Droplets that opt in to a reserved IP or a data volume.
  droplets_with_reserved_ip = { for key, droplet in local.droplets : key => droplet if droplet.reserved_ip }
  droplets_with_volume      = { for key, droplet in local.droplets : key => droplet if droplet.volume_size_gb != null }

  # Existing SSH keys on the DigitalOcean account, looked up by name.
  ssh_key_names = [
    "picon___id_rsa.pub",
  ]
}

data "digitalocean_ssh_key" "this" {
  for_each = toset(local.ssh_key_names)
  name     = each.value
}

resource "digitalocean_droplet" "this" {
  for_each = local.droplets

  name        = "${each.value.stage}-${each.key}"
  region      = local.region
  size        = each.value.size
  image       = each.value.image
  monitoring  = true
  resize_disk = each.value.resize_disk
  tags        = concat([each.value.stage], try(each.value.tags, []))
  ssh_keys    = [for key in data.digitalocean_ssh_key.this : key.id]
  # Attach the data volume at creation so DigitalOcean mounts it automatically
  # (the volume itself is formatted at volume creation).
  volume_ids = contains(keys(local.droplets_with_volume), each.key) ? [digitalocean_volume.this[each.key].id] : []

  lifecycle {
    # locals cannot carry a validation block, so the stage list is checked
    # here. The plan fails before anything is created or changed.
    precondition {
      condition     = contains(local.stages, each.value.stage)
      error_message = "Droplet \"${each.key}\" has stage \"${each.value.stage}\", but the stage must be one of ${join(", ", local.stages)} (docs/cloud/domain-naming.md)."
    }
  }
}
