output "droplet_ipv4_addresses" {
  description = "Public IPv4 address of each droplet, keyed by droplet name"
  value       = { for droplet in digitalocean_droplet.this : droplet.name => droplet.ipv4_address }
}

output "reserved_ip_addresses" {
  description = "Reserved IP (stable public address) of each droplet, keyed by droplet name"
  value       = { for key, ip in digitalocean_reserved_ip.this : digitalocean_droplet.this[key].name => ip.ip_address }
}

output "volume_mount_paths" {
  description = "Mount path of the data volume of each droplet, keyed by droplet name"
  value       = { for key, volume in digitalocean_volume.this : digitalocean_droplet.this[key].name => "/mnt/${replace(volume.name, "-", "_")}" }
}

output "dns_zone" {
  description = "Name of the DigitalOcean DNS zone that holds the app records"
  value       = digitalocean_domain.this.name
}

output "dns_records" {
  description = "IPv4 address of each A record in the DigitalOcean DNS zone, keyed by FQDN"
  value       = { for record in digitalocean_record.a : record.fqdn => record.value }
}
