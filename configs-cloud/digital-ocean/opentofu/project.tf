data "digitalocean_project" "this" {
  name = "sommerfeld.io"
}

resource "digitalocean_project_resources" "this" {
  project = data.digitalocean_project.this.id
  resources = concat(
    [for droplet in digitalocean_droplet.this : droplet.urn],
    [for volume in digitalocean_volume.this : volume.urn],
    [for ip in digitalocean_reserved_ip.this : ip.urn],
  )
}
