data "digitalocean_project" "this" {
  name = "sommerfeld.io"
}

resource "digitalocean_project_resources" "this" {
  project   = data.digitalocean_project.this.id
  resources = [for droplet in digitalocean_droplet.this : droplet.urn]
}
