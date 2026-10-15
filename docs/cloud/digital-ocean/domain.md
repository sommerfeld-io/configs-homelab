# Domain

The fantasy hockey app has the domain `fantasy-hockey.prod.do.sommerfeld.app`. An A record points it at the droplet's reserved IP. Users reach the app by this name instead of by IP: Caddy serves it at `https://fantasy-hockey.prod.do.sommerfeld.app` with a Let's Encrypt certificate and answers requests to the reserved IP with 404 (see [Deployment](deployment.md)).

## Record

| Name                                    | Type | Value                                    | TTL  | Where                     |
|-----------------------------------------|------|------------------------------------------|------|---------------------------|
| `fantasy-hockey.prod.do.sommerfeld.app` | `A`  | The reserved IP of `prod-fantasy-hockey` | 7200 | DNS of all-inkl.com (KAS) |

Hostnames follow the pattern `<app>.<stage>.do.sommerfeld.app` (see [Domain Naming](../domain-naming.md)), built from the same parts as the droplet name `<stage>-<app>` (see [Droplet](droplet.md)): `<app>` is the key of the droplet in the `droplets` map of `droplets.tf` (`fantasy-hockey`), `<stage>` is the droplet's `stage` (also its tag and the Alloy label), and `do` stands for DigitalOcean. A later `test` droplet for the same app gets `fantasy-hockey.test.do.sommerfeld.app`.

The record points at the reserved IP, not at the droplet's own IPv4. The reserved IP survives a droplet replacement, so a [Replacement](replacement.md) needs no DNS change. A new reserved IP needs one: changing the region, the `stage` or the map key gives the droplet a new reserved IP or a new name (see [Droplet](droplet.md)), and then the record has to be changed or a new one created. Read the reserved IP with:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses
```

There is no AAAA record: the reserved IP is IPv4 only.

## Why DNS Is Not in OpenTofu

`sommerfeld.app` is registered and hosted at the web hosting provider all-inkl.com (nameservers `ns5.kasserver.com` and `ns6.kasserver.com`). DNS stays there, and OpenTofu does not manage it. So the record is created by hand, and the DigitalOcean API token needs no `domain` scope (see [API Token](api-token.md)).

The `.app` TLD is on the browsers' HSTS preload list: browsers open `.app` domains only over HTTPS, never over plain HTTP. A `.app` name opens in a browser only when the droplet serves HTTPS for it, which Caddy does.

The zone has no CAA record (checked 2026-10-15 for the name and every parent up to `sommerfeld.app`), so any certificate authority, including Let's Encrypt, may issue certificates for the name. A CAA record added later must allow `letsencrypt.org`.

## Create the Record

1. Log in to the KAS at `https://kas.all-inkl.com`.
2. Open Tools → DNS-Einstellungen and edit the domain `sommerfeld.app`.
3. Create a new DNS record:
    - Name: `fantasy-hockey.prod.do` (without `.sommerfeld.app`, the KAS appends the domain)
    - Type: `A`
    - Data: the reserved IP
4. Save.

Create a DNS record, not a KAS subdomain (Domain → Subdomains). A KAS subdomain points the name at the all-inkl web server and collides with the A record.

The zone has a wildcard record that points every other name at the all-inkl web server (`85.13.131.235`). The A record for this exact name takes precedence over it. Before the record exists, or while resolvers still cache the wildcard answer (TTL up to 2 hours), the name resolves to `85.13.131.235`.

## Check

Ask public resolvers, not the home router: the Fritz!Box resolver may still cache the wildcard answer. `dig` is not installed in the devcontainer, so the check uses DNS over HTTPS against Google and Cloudflare:

```bash
curl -s 'https://dns.google/resolve?name=fantasy-hockey.prod.do.sommerfeld.app&type=A' | python3 -m json.tool
curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=fantasy-hockey.prod.do.sommerfeld.app&type=A' | python3 -m json.tool
```

Both answers have `"data"` equal to the reserved IP from `tofu output reserved_ip_addresses`. `85.13.131.235` means the record is missing or a resolver still caches the wildcard answer. With `dig` available: `dig +short fantasy-hockey.prod.do.sommerfeld.app` prints the reserved IP.

The deploy checks the record too: before it writes anything, it resolves the name on the droplet and stops when the reserved IP is not among the answers, so Caddy never asks Let's Encrypt for a certificate it cannot get (see [DNS Check](deployment.md#dns-check)). The domain is derived from the droplet name, so a new droplet needs its record before its first deploy.

## Remove the Record

Delete the record in the KAS (Tools → DNS-Einstellungen, `sommerfeld.app`) when the droplet is retired or its reserved IP is released. A record that points at a released IP points at an address DigitalOcean can give to another customer, who could then serve content under the name. A [Replacement](replacement.md) keeps the reserved IP, so the record stays.
