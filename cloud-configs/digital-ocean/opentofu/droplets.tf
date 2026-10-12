locals {
  # The stage builds the droplet name prefix and the tag. Define it only here.
  stage  = "prod"
  region = "fra1"

  # One entry per droplet. The key becomes the name suffix: "<stage>-<key>".
  droplets = {
    fantasy-hockey = {
      size  = "s-1vcpu-1gb"
      image = "ubuntu-26-04-x64"
      # Resize CPU and RAM only. A grown disk can never shrink again, so a
      # later downsize would be impossible without replacing the droplet.
      resize_disk = false
    }
  }

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

  name        = "${local.stage}-${each.key}"
  region      = local.region
  size        = each.value.size
  image       = each.value.image
  monitoring  = true
  resize_disk = each.value.resize_disk
  tags        = [local.stage]
  ssh_keys    = [for key in data.digitalocean_ssh_key.this : key.id]
}
