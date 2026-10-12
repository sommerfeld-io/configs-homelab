output "droplet_ipv4_addresses" {
  description = "Public IPv4 address of each droplet, keyed by droplet name"
  value       = { for droplet in digitalocean_droplet.this : droplet.name => droplet.ipv4_address }
}
