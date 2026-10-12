# One reserved IP per droplet: the stable public address.
resource "digitalocean_reserved_ip" "this" {
  for_each = local.droplets

  region = local.region

  # The address must survive droplet replacements.
  lifecycle {
    prevent_destroy = true
  }
}

# A separate assignment, so a replaced droplet gets the same address again
# without touching the reserved IP itself.
resource "digitalocean_reserved_ip_assignment" "this" {
  for_each = local.droplets

  ip_address = digitalocean_reserved_ip.this[each.key].ip_address
  droplet_id = digitalocean_droplet.this[each.key].id
}
