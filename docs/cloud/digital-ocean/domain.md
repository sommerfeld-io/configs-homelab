# Domain

The fantasy hockey app has the domain `fantasy-hockey.prod.do.sommerfeld.app`. An A record points it at the droplet's reserved IP. Users reach the app by this name instead of by IP: Caddy serves it at `https://fantasy-hockey.prod.do.sommerfeld.app` with a Let's Encrypt certificate. It answers `http://<reserved-ip>` with 404, and `https://<reserved-ip>` fails the TLS handshake, because Caddy has no certificate for the IP (see [Deployment](deployment.md)).

## Record

| Name                                    | Type | Value                                    | TTL  | Where                     |
|-----------------------------------------|------|------------------------------------------|------|---------------------------|
| `fantasy-hockey.prod.do.sommerfeld.app` | `A`  | The reserved IP of `prod-fantasy-hockey` | 7200 | DNS of all-inkl.com (KAS) |

Hostnames follow the pattern `<app>.<stage>.do.sommerfeld.app` (see [Domain Naming](../domain-naming.md)), built from the same parts as the droplet name `<stage>-<app>` (see [Droplet](droplet.md)): `<app>` is the key of the droplet in the `droplets` map of `droplets.tf` (`fantasy-hockey`), `<stage>` is the droplet's `stage` (also its tag and the Alloy label), and `do` stands for DigitalOcean. A later `test` droplet for the same app gets `fantasy-hockey.test.do.sommerfeld.app`. It needs `reserved_ip = true` in `droplets.tf`, unlike the throwaway `example-scratch` template in [Droplet](droplet.md#reserved_ip): the deploy stops when the droplet has no reserved IP, and the record has to point at one.

The record points at the reserved IP, not at the droplet's own IPv4. The reserved IP survives a droplet replacement, so a [Replacement](replacement.md) needs no DNS change. A new reserved IP needs one: changing the region, the `stage` or the map key gives the droplet a new reserved IP or a new name (see [Droplet](droplet.md)). The record in the DigitalOcean zone follows automatically with the next apply (see [DNS Zone](dns-zone.md)), but the KAS record on this page still has to be changed or a new one created by hand until Story 8.2. Read the reserved IP with:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses
```

There is no AAAA record: the reserved IP is IPv4 only.

OpenTofu now also declares this record in the DigitalOcean zone `do.sommerfeld.app` (see [DNS Zone](dns-zone.md)), but that zone is not delegated yet: the KAS record on this page remains authoritative until Story 8.2.

## Where the Public Record Lives

`sommerfeld.app` is registered and hosted at the web hosting provider all-inkl.com (nameservers `ns5.kasserver.com` and `ns6.kasserver.com`). The zone stays there, and OpenTofu does not manage it. Until Story 8.2 delegates `do.sommerfeld.app`, the record on this page is kept by hand in the KAS and is the one the public sees. OpenTofu manages only the DigitalOcean zone `do.sommerfeld.app`, which is why the DigitalOcean API token needs the `domain` scope (see [DNS Zone](dns-zone.md) and [API Token](api-token.md)).

The `.app` TLD is on the browsers' HSTS preload list: browsers open `.app` domains only over HTTPS, never over plain HTTP. A `.app` name opens in a browser only when the droplet serves HTTPS for it, which Caddy does.

The KAS zone has no CAA record (checked 2026-10-15 for the name and every parent up to `sommerfeld.app`), so today any certificate authority, including Let's Encrypt, may issue certificates for the name. The DigitalOcean zone has `CAA 0 issue "letsencrypt.org"` at `do.sommerfeld.app`, which takes effect once Story 8.2 delegates the zone (see [DNS Zone](dns-zone.md#ttl-and-caa)).

## Create the Record

1. Log in to the KAS at `https://kas.all-inkl.com`.
2. Open Tools → DNS-Einstellungen and edit the domain `sommerfeld.app`.
3. Create a new DNS record:
    - Name: `fantasy-hockey.prod.do` (without `.sommerfeld.app`, the KAS appends the domain)
    - Type: `A`
    - Data: the reserved IP
    - TTL: `7200`, as in the Record table
4. Save.

The TTL also decides how long resolvers keep an old answer: after the record changes, for example to a new reserved IP, the deploy's DNS check and Let's Encrypt may see the old address for up to 2 hours.

Create a DNS record, not a KAS subdomain (Domain → Subdomains). A KAS subdomain points the name at the all-inkl web server and collides with the A record.

The zone has a wildcard record `*.sommerfeld.app`, a CNAME to the all-inkl web host `w00f8074.kasserver.com`, that answers every other name. The A record for this exact name takes precedence over it. Before the record exists, or while resolvers still cache the wildcard answer (TTL up to 2 hours), the name resolves through that CNAME to the web host's address (`85.13.131.235` on 2026-10-15; all-inkl can change it).

## Check

Ask public resolvers, not the home router: the Fritz!Box resolver may still cache the wildcard answer. `dig` is not installed in the devcontainer, so the check uses DNS over HTTPS against Google and Cloudflare:

```bash
curl -s 'https://dns.google/resolve?name=fantasy-hockey.prod.do.sommerfeld.app&type=A' | python3 -m json.tool
curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=fantasy-hockey.prod.do.sommerfeld.app&type=A' | python3 -m json.tool
```

Both answers have exactly one A record whose `"data"` is the reserved IP from `tofu output reserved_ip_addresses`. A CNAME to a `*.kasserver.com` host in the answer means the record is missing or a resolver still caches the wildcard answer. The same queries with `type=AAAA` return no AAAA record: Let's Encrypt prefers IPv6, and the deploy's check sees only IPv4. On the droplet, `getent ahostsv4 fantasy-hockey.prod.do.sommerfeld.app` shows what the deploy's check sees.

The deploy checks the record too: before it writes anything, it resolves the name through the droplet's resolver and stops unless the answer is exactly the reserved IP, so Caddy does not start with a name that points elsewhere (see [DNS Check](deployment.md#dns-check)). The check runs only at deploy time: it does not cover renewals, CAA records, AAAA records or whether ports 80 and 443 are reachable.

The domain is derived from the droplet name, so a new droplet needs its record before its first deploy. The reserved IP exists only after the OpenTofu apply, so a new droplet takes this order:

1. `task cloud:digital-ocean:opentofu:apply` creates the droplet and its reserved IP.
2. Create the record with the IP from `tofu output reserved_ip_addresses` (see [Create the Record](#create-the-record)).
3. Wait until the check above returns the reserved IP, and `ssh root@<reserved-ip> getent ahostsv4 fantasy-hockey.prod.do.sommerfeld.app` returns only the reserved IP too: the deploy checks through the droplet's resolver. Resolvers that already asked for the name may cache the wildcard answer for up to 2 hours.
4. `task cloud:deploy:all` (or the provisioning and the app deploy on their own).

## Remove the Record

Delete the record in the KAS (Tools → DNS-Einstellungen, `sommerfeld.app`) when the droplet is retired or its reserved IP is released. A record that points at a released IP points at an address DigitalOcean can give to another customer, who could then serve content under the name. A [Replacement](replacement.md) keeps the reserved IP, so the record stays.
