locals {
  region = "fra1"

  # One entry per droplet. The droplet name is "<stage>-<key>".
  #
  # Options (all required):
  #   stage          Label of the droplet, e.g. "prod" or "test".
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
  droplets = {
    fantasy-hockey = {
      stage          = "prod"
      size           = "s-1vcpu-1gb"
      image          = "ubuntu-26-04-x64"
      resize_disk    = false
      reserved_ip    = true
      volume_size_gb = 2
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
  tags        = [each.value.stage]
  ssh_keys    = [for key in data.digitalocean_ssh_key.this : key.id]
  # Attach the data volume at creation so DigitalOcean mounts it automatically
  # (the volume itself is formatted at volume creation).
  volume_ids = contains(keys(local.droplets_with_volume), each.key) ? [digitalocean_volume.this[each.key].id] : []
}
