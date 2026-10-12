output "droplet_ipv4_addresses" {
  description = "Public IPv4 address of each droplet, keyed by droplet name"
  value       = { for droplet in digitalocean_droplet.this : droplet.name => droplet.ipv4_address }
}

output "reserved_ip_addresses" {
  description = "Reserved IP (stable public address) of each droplet, keyed by droplet name"
  value       = { for key, droplet in digitalocean_droplet.this : droplet.name => digitalocean_reserved_ip.this[key].ip_address }
}

output "volume_mount_paths" {
  description = "Mount path of the data volume of each droplet, keyed by droplet name"
  value       = { for key, droplet in digitalocean_droplet.this : droplet.name => "/mnt/${replace(digitalocean_volume.this[key].name, "-", "_")}" }
}
