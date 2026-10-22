locals {
  # The DigitalOcean DNS zone. sommerfeld.app itself stays at all-inkl.com;
  # only this subdomain is delegated to ns1-3.digitalocean.com with NS records
  # in the KAS (docs/cloud/digital-ocean/dns-delegation.md).
  dns_zone = "do.sommerfeld.app"

  # A wrong A record heals five minutes after a fix. The CAA record rarely
  # changes, so it keeps a longer TTL.
  dns_ttl     = 300
  dns_caa_ttl = 3600

  # Certificate authorities allowed to issue for the zone and every name below
  # it, one CAA "0 issue" record each. Caddy configures no issuer, so it tries
  # Let's Encrypt first and falls back to ZeroSSL, whose CAA identifier is
  # sectigo.com. Without the second entry the fallback would be refused.
  dns_caa_issuers = ["letsencrypt.org", "sectigo.com"]

  # One A record <key>.<stage> per droplet with a reserved IP, the hostname
  # pattern of docs/cloud/domain-naming.md. Name relative to the zone =>
  # droplet key. A droplet without a reserved IP gets no record.
  dns_droplet_records = { for key, droplet in local.droplets_with_reserved_ip : "${key}.${droplet.stage}" => key }

  # Extra names of a droplet from its optional dns_aliases list. Every alias
  # must end in .<stage> of its droplet (precondition below). The grouping
  # (...) keeps a duplicate alias from failing here, so the precondition can
  # name it instead.
  dns_alias_list = flatten([
    for key, droplet in local.droplets : [
      for alias in try(droplet.dns_aliases, []) : {
        name        = alias
        key         = key
        stage       = droplet.stage
        reserved_ip = droplet.reserved_ip
      }
    ]
  ])
  dns_alias_records = { for alias in local.dns_alias_list : alias.name => alias.key... if alias.reserved_ip }

  # Names that point at addresses this configuration does not manage. Name
  # relative to the zone => IPv4 address. Only hosts the operator controls
  # may be listed, each with a comment naming the owner of the address.
  dns_external_records = {
    # "status.prod" = "203.0.113.10" # owner: <who runs this host>
  }

  # Every record name from the three sources, duplicates included, for the
  # duplicate check on the zone.
  dns_record_names = concat(
    keys(local.dns_droplet_records),
    [for alias in local.dns_alias_list : alias.name],
    keys(local.dns_external_records),
  )

  # Name relative to the zone => IPv4 address. Droplet names and aliases
  # reference the reserved IP, never a copied address, so a reserved IP
  # change is an in-place update of the record.
  dns_a_records = merge(
    { for name, key in local.dns_droplet_records : name => digitalocean_reserved_ip.this[key].ip_address },
    { for name, droplet_keys in local.dns_alias_records : name => digitalocean_reserved_ip.this[droplet_keys[0]].ip_address },
    local.dns_external_records,
  )
}

# The zone. It is authoritative because the parent zone sommerfeld.app at
# all-inkl.com delegates "do" to DigitalOcean with NS records, set by hand in
# the KAS (docs/cloud/digital-ocean/dns-delegation.md).
# No ip_address: that argument would create an apex A record outside the
# records below.
resource "digitalocean_domain" "this" {
  name = local.dns_zone

  lifecycle {
    # Deleting the zone deletes every record in it.
    prevent_destroy = true

    # locals cannot carry a validation block, so the record inputs are
    # checked here. The plan fails before anything is created or changed.
    precondition {
      condition     = length(local.dns_record_names) == length(distinct(local.dns_record_names))
      error_message = "DNS record names must be unique across droplets, dns_aliases and dns_external_records, but these appear more than once: ${join(", ", distinct([for name in local.dns_record_names : name if length([for other in local.dns_record_names : other if other == name]) > 1]))}."
    }

    precondition {
      condition     = alltrue([for alias in local.dns_alias_list : endswith(alias.name, ".${alias.stage}") && alias.name != ".${alias.stage}"])
      error_message = "Every dns_aliases entry must end in .<stage> of its droplet (docs/cloud/domain-naming.md), but these do not: ${join(", ", [for alias in local.dns_alias_list : "\"${alias.name}\" on \"${alias.key}\" (stage ${alias.stage})" if !endswith(alias.name, ".${alias.stage}") || alias.name == ".${alias.stage}"])}."
    }

    precondition {
      condition     = alltrue([for alias in local.dns_alias_list : alias.reserved_ip])
      error_message = "dns_aliases need a droplet with reserved_ip = true, because a record points at the reserved IP. These droplets have aliases but no reserved IP: ${join(", ", distinct([for alias in local.dns_alias_list : alias.key if !alias.reserved_ip]))}."
    }

    precondition {
      condition     = alltrue([for name, ip in local.dns_external_records : can(cidrnetmask("${ip}/32"))])
      error_message = "Every dns_external_records value must be an IPv4 address, but these are not: ${join(", ", [for name, ip in local.dns_external_records : "${name} = \"${ip}\"" if !can(cidrnetmask("${ip}/32"))])}."
    }
  }
}

# One A record per name. The key is the name relative to the zone and never
# depends on a value known only after apply, so an address change is an
# in-place update, never a replacement.
resource "digitalocean_record" "a" {
  for_each = local.dns_a_records

  domain = digitalocean_domain.this.id
  type   = "A"
  name   = each.key
  value  = each.value
  ttl    = local.dns_ttl
}

# Only the issuers Caddy uses may issue certificates for the zone and every
# name below it. Without these records, CAA lookups would fall through to the
# parent zone. The provider reads the value back with a trailing dot, so it is
# written with one to keep the next plan clean.
resource "digitalocean_record" "caa" {
  for_each = toset(local.dns_caa_issuers)

  domain = digitalocean_domain.this.id
  type   = "CAA"
  name   = "@"
  flags  = 0
  tag    = "issue"
  value  = "${each.key}."
  ttl    = local.dns_caa_ttl
}

# Story 8.1 created the Let's Encrypt record as a single resource. This keeps
# it in place instead of destroying and recreating it under the new address.
moved {
  from = digitalocean_record.caa
  to   = digitalocean_record.caa["letsencrypt.org"]
}
