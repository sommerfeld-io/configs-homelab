# One data volume per droplet. The droplet attaches it at creation through
# volume_ids, so DigitalOcean mounts it under /mnt/<volume-name> (hyphens
# become underscores). initial_filesystem_type formats it at volume creation.
resource "digitalocean_volume" "this" {
  for_each = local.droplets_with_volume

  name                    = "${each.value.stage}-${each.key}-data"
  region                  = local.region
  size                    = each.value.volume_size_gb
  initial_filesystem_type = "ext4"

  # The volume holds the data and must survive droplet replacements.
  lifecycle {
    prevent_destroy = true
  }
}
