# Domain

The fantasy hockey app has the domain `fantasy-hockey.prod.do.sommerfeld.app`. An A record points it at the droplet's reserved IP. Users reach the app by this name instead of by IP: Caddy serves it at `https://fantasy-hockey.prod.do.sommerfeld.app` with a Let's Encrypt certificate. It answers `http://<reserved-ip>` with 404, and `https://<reserved-ip>` fails the TLS handshake, because Caddy has no certificate for the IP (see [Deployment](deployment.md)).

## Record

| Name                                    | Type | Value                                    | TTL | Where                                                   |
|-----------------------------------------|------|------------------------------------------|-----|---------------------------------------------------------|
| `fantasy-hockey.prod.do.sommerfeld.app` | `A`  | The reserved IP of `prod-fantasy-hockey` | 300 | DigitalOcean zone `do.sommerfeld.app`, OpenTofu-managed |

The record is declared in OpenTofu (`configs-cloud/digital-ocean/opentofu/dns.tf`) and derived from the droplet map: every droplet with `reserved_ip = true` gets one. Nobody creates it by hand. Read the declared records with:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_records
tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses
```

Hostnames follow the pattern `<app>.<stage>.do.sommerfeld.app` (see [Domain Naming](../domain-naming.md)), built from the same parts as the droplet name `<stage>-<app>` (see [Droplet](droplet.md)): `<app>` is the key of the droplet in the `droplets` map of `droplets.tf` (`fantasy-hockey`), `<stage>` is the droplet's `stage` (also its tag and the Alloy label), and `do` stands for DigitalOcean. A later `test` droplet for the same app gets its own key and record (see [Same App in Another Stage](dns-zone.md#same-app-in-another-stage)). It needs `reserved_ip = true` in `droplets.tf`, unlike the throwaway `example-scratch` template in [Droplet](droplet.md#reserved_ip): the deploy stops when the droplet has no reserved IP, and a droplet without one gets no record.

The record points at the reserved IP, not at the droplet's own IPv4. The reserved IP survives a droplet replacement, so a [Replacement](replacement.md) changes no record. A new reserved IP keeps the record name, so the same apply changes the record in place (`~ value`). The region is shared by every droplet and reserved IP, which have `prevent_destroy`, so a region change fails the plan until that is lifted and then changes every app's record (see [Update a Target IP](dns-zone.md#update-a-target-ip)). A new `stage` or map key changes the record name: the old record is destroyed and a new one created (see [Move an App to Another Droplet](dns-zone.md#move-an-app-to-another-droplet)). Resolvers keep the old answer for the rest of the TTL, up to 300 s.

There is no AAAA record: the reserved IP is IPv4 only.

## Where DNS Lives

`sommerfeld.app` is registered and hosted at the web hosting provider all-inkl.com (nameservers `ns5.kasserver.com` and `ns6.kasserver.com`). That zone stays there, and OpenTofu does not manage it. It delegates the subdomain `do.sommerfeld.app` to DigitalOcean DNS (`ns1`/`ns2`/`ns3.digitalocean.com`) with three NS records set by hand in the KAS. Every name at or below `do.sommerfeld.app`, this record included, is declared in OpenTofu in the delegated zone. That is why the DigitalOcean API token needs the `domain` scope (see [API Token](api-token.md)).

- [DNS Zone](dns-zone.md): the DigitalOcean zone, its records, the how-tos and the checks.
- [DNS Delegation](dns-delegation.md): the NS records in the KAS, the migration runbook and the rollback.

The `.app` TLD is on the browsers' HSTS preload list: browsers open `.app` domains only over HTTPS, never over plain HTTP. A `.app` name opens in a browser only when the droplet serves HTTPS for it, which Caddy does.

The DigitalOcean zone serves `CAA 0 issue "letsencrypt.org"` and `CAA 0 issue "sectigo.com"` at `do.sommerfeld.app`: only Let's Encrypt and ZeroSSL (Caddy's fallback issuer, CAA identifier `sectigo.com`) may issue certificates for the app's name (see [TTL and CAA](dns-zone.md#ttl-and-caa)). CAA lookups for every name under `do` stop at `do.sommerfeld.app`.

The parent zone has a wildcard record `*.sommerfeld.app`, a CNAME to the all-inkl web host `w00f8074.kasserver.com` (`85.13.131.235` on 2026-10-22; all-inkl can change it). It applies only outside `do`: by DNS rules a wildcard never matches at or below a delegation point. A name under `do` that is not declared returns NXDOMAIN, not the web host.

## Create the Record

Add the droplet to `droplets.tf` with `reserved_ip = true`, then plan, review and apply: the record is created with the droplet and its reserved IP (see [Add an App Hostname](dns-zone.md#add-an-app-hostname)). Other cases (an alias, an external IP, a moved app) are in the [DNS Zone how-tos](dns-zone.md#how-tos).

Do not create records for names under `do` in the KAS: the delegation hides them. The KAS answers queries for those names with a referral to DigitalOcean.

## Check

Ask both the authoritative nameservers and public resolvers, not the home router: the Fritz!Box resolver may still cache an old answer. One resolver is never enough.

```bash
task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns5.kasserver.com fantasy-hockey.prod.do.sommerfeld.app A
curl -s 'https://dns.google/resolve?name=fantasy-hockey.prod.do.sommerfeld.app&type=A' | python3 -m json.tool
curl -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=fantasy-hockey.prod.do.sommerfeld.app&type=A' | python3 -m json.tool
```

- `ns1.digitalocean.com` answers with `flags: qr aa` and the reserved IP from `tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses`.
- `ns5.kasserver.com` answers with a referral: no `aa`, and the three DigitalOcean nameservers in the authority section.
- Google and Cloudflare return exactly one A record whose `"data"` is the reserved IP. The same queries with `type=AAAA` return no AAAA record: Let's Encrypt prefers IPv6, and the deploy's check sees only IPv4.
- On the droplet, `getent ahostsv4 fantasy-hockey.prod.do.sommerfeld.app` shows what the deploy's check sees.

The full set of checks, including `+trace` and CAA, is in [DNS Delegation](dns-delegation.md#verification-commands).

The deploy checks the record too: before it writes anything, it resolves the name through the droplet's resolver and stops unless the answer is exactly the reserved IP, so Caddy does not start with a name that points elsewhere (see [DNS Check](deployment.md#dns-check)). The check runs only at deploy time: it does not cover renewals, CAA records, AAAA records or whether ports 80 and 443 are reachable.

A new droplet gets its record in the same OpenTofu apply that creates its reserved IP, so `task cloud:deploy:all` can run in one go:

1. `task cloud:digital-ocean:opentofu:apply` creates the droplet, its reserved IP and its A record.
2. The app deployment resolves the name on the droplet. If a resolver asked for the name before the record existed, it caches the NXDOMAIN for up to the zone's negative-caching TTL of 1800 s, and the deploy stops at the DNS check. Wait, check as above, then run `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` again.

## Remove the Record

The record goes in the same apply as the droplet: removing the droplet entry removes its record (see [Remove a Hostname](dns-zone.md#remove-a-hostname)). Never leave a record on a released reserved IP: DigitalOcean can give the address to another customer, who could then serve content under the name. A [Replacement](replacement.md) keeps the reserved IP, so the record stays.

## History

| Date       | Change                                                                                                                                                                                                                                                                          |
|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2026-10-15 | The A record is created by hand in the KAS zone `sommerfeld.app` (Story 7.1), TTL 7200                                                                                                                                                                                          |
| 2026-10-22 | OpenTofu creates the DigitalOcean zone `do.sommerfeld.app` with the same record, not yet delegated (Story 8.1)                                                                                                                                                                  |
| 2026-10-22 | OpenTofu adds `CAA 0 issue "sectigo.com"` for ZeroSSL (Story 8.2, [M8a](dns-delegation.md#m8a-allow-zerossl-in-the-caa-records))                                                                                                                                                |
| 2026-10-22 | The KAS delegates `do` to DigitalOcean with three NS records at 18:06 UTC (Story 8.2, [M10](dns-delegation.md#m10-add-the-ns-records))                                                                                                                                          |
| 2026-10-22 | The hand-made KAS A record is deleted at 18:10 UTC (Story 8.2, [M14](dns-delegation.md#m14-delete-the-obsolete-kas-a-record))                                                                                                                                                   |
| 2026-10-22 | The M13 wait of 2 × 7200 s was skipped: the A record was deleted at 18:10:02 UTC, 4 min after M10 (18:06:05 UTC). Harmless, because at 18:06–18:07 UTC (M11) both KAS nameservers already referred, so the record was occluded and any cached copy held the same IP (Story 8.2) |
| 2026-10-28 | Runbook [M13](dns-delegation.md#m13-confirm-the-delegation-is-authoritative) checks the referral on both KAS nameservers and the trace instead of waiting 2 × TTL (Epic 8 retro item 38)                                                                                        |
