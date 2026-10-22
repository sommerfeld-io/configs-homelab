# DNS Delegation

The parent zone `sommerfeld.app` at all-inkl.com delegates the subdomain `do.sommerfeld.app` to DigitalOcean DNS with three NS records. From then on, DigitalOcean answers every name at or below `do.sommerfeld.app`, and OpenTofu declares those names (see [DNS Zone](dns-zone.md)). all-inkl.com keeps the registration, the parent zone and every name outside `do`.

This page is the migration runbook for the switch from the hand-made KAS record (Story 7.1) to the delegated zone, and it stays the recovery reference afterwards. The KAS is the all-inkl.com customer administration at `https://kas.all-inkl.com`. OpenTofu has no provider for it here, so every KAS step is manual. The dates the delegation went live and the KAS A record was removed are recorded in [Domain](domain.md#history).

## Responsibilities

| Who                         | Owns                                                                                                                                       |
|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| all-inkl.com (KAS)          | the registration of `sommerfeld.app`, the parent zone on `ns5`/`ns6.kasserver.com`, the three NS records for `do`, every name outside `do` |
| DigitalOcean DNS            | the zone `do.sommerfeld.app` on `ns1`/`ns2`/`ns3.digitalocean.com` and every record in it                                                  |
| OpenTofu (`dns.tf`)         | the zone and its records, through the DigitalOcean API                                                                                     |
| The operator (manual)       | the KAS steps, the DigitalOcean API token with the `domain` scope, every `tofu apply`                                                      |
| The agent (documented only) | the runbook, the docs and the code; it never logs in to the KAS, never applies and never deploys                                           |

## Delegation

The parent zone `sommerfeld.app` holds exactly these records for `do`, created in the KAS under Tools → DNS-Einstellungen → `sommerfeld.app` → "Neuen DNS-Eintrag":

| Name | Type | Prio | Data                    | TTL                    |
|------|------|------|-------------------------|------------------------|
| `do` | `NS` | `0`  | `ns1.digitalocean.com.` | 7200 (the KAS default) |
| `do` | `NS` | `0`  | `ns2.digitalocean.com.` | 7200 (the KAS default) |
| `do` | `NS` | `0`  | `ns3.digitalocean.com.` | 7200 (the KAS default) |

- The name is relative: the KAS appends `.sommerfeld.app`.
- **The trailing dot in Data is required** ([all-inkl tutorial](https://all-inkl.com/en/support/tutorials/kas/tools/dns-tools/how-to-change-the-name-servers-for-a-subdomain_155.html)). Without it, the KAS would read the name relative to the zone.
- The three nameservers are the same for every DigitalOcean zone ([DNS registrars](https://docs.digitalocean.com/products/networking/dns/getting-started/dns-registrars/)), so a zone that is recreated at DigitalOcean needs no KAS change.
- No glue records: the nameservers live under `digitalocean.com`, outside the delegated zone.
- No DS record for `do`, ever: DigitalOcean DNS cannot sign zones, so a DS record would make every name under `do` fail validation (see [DNSSEC](#dnssec)).

By DNS rules, the wildcard `*.sommerfeld.app` no longer matches anything at or below `do`. It keeps answering every other missing name, for example `x.sommerfeld.app`.

## Migration Runbook

Story 8.1 did M1 to M6: the token with the `domain` scope, the zone check, the state backup, the apply, the authoritative check and the public check. The NS hostnames are `ns1`/`ns2`/`ns3.digitalocean.com.` (TTL 1800) and the SOA is `ns1.digitalocean.com. hostmaster.do.sommerfeld.app. 0 10800 3600 604800 1800`, so the zone's negative-caching TTL is 1800 s. The runbook continues with M7. Do the steps in order.

Why this order: the NS records are added while the old KAS A record still exists. Both sides answer the same IP, so caching, propagation or a resolver on either side cannot produce a wrong address. Deleting the A record first would expose the wildcard (`w00f8074.kasserver.com`, `85.13.131.235` on 2026-10-22) for up to 7200 s to every resolver that has not yet seen the NS records. That breaks HTTPS and could make a Caddy renewal fail validation.

| Step | Who                         | Where                                  | Repeat-safe                    | Outage risk                      | Rollback                                     |
|------|-----------------------------|----------------------------------------|--------------------------------|----------------------------------|----------------------------------------------|
| M7   | operator (manual)           | KAS                                    | yes, read-only                 | none                             | none needed                                  |
| M8   | operator (manual)           | devcontainer                           | yes, read-only                 | none                             | none needed                                  |
| M8a  | operator (manual), OpenTofu | devcontainer                           | yes, a second plan is empty    | none, the zone is not public yet | [R2](#r2-wrong-record)                       |
| M9   | operator (manual)           | KAS                                    | yes, read-only                 | none                             | none needed                                  |
| M10  | operator (manual)           | KAS                                    | yes, the same three records    | none, both sides answer alike    | [R1](#r1-broken-delegation)                  |
| M11  | operator (manual)           | devcontainer                           | yes, read-only                 | none                             | [R1](#r1-broken-delegation)                  |
| M12  | operator (manual)           | outside the home network, devcontainer | yes, read-only                 | none                             | [R1](#r1-broken-delegation)                  |
| M13  | operator (manual)           | calendar, then as M11 and M12          | yes                            | none                             | [R1](#r1-broken-delegation)                  |
| M14  | operator (manual)           | KAS                                    | yes, deleting twice is a no-op | only if the delegation is broken | [R3](#r3-failure-after-the-a-record-is-gone) |
| M15  | operator (manual)           | devcontainer                           | yes, idempotent                | none                             | none needed                                  |
| M16  | operator (manual)           | devcontainer                           | yes                            | none                             | none needed                                  |

### M7: Inventory the KAS Zone

- **When:** before anything changes.
- **Where:** KAS → Tools → DNS-Einstellungen → `sommerfeld.app` (edit), then Domain → Subdomains.
- **Action (manual, read-only):** screenshot or copy every record of the zone with its TTL, especially every name that is `do` or ends in `.do`, the wildcard `*`, and any NS, CAA or TXT record. Under Domain → Subdomains, note whether a KAS subdomain `do.sommerfeld.app` or `*.do.sommerfeld.app` exists: it would collide with the NS records.
- **Expected:** on 2026-10-22 the public view (DoH) was: the only record under `do` is A `fantasy-hockey.prod.do` `129.212.195.118` TTL 7200; `sommerfeld.app` A `85.13.131.235`; `www.sommerfeld.app` through the wildcard CNAME `w00f8074.kasserver.com`; MX `10 w00f8074.kasserver.com.`; NS `ns5`/`ns6.kasserver.com`; no DS, no CAA.
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** none needed.

### M8: Record the Baseline

- **When:** after M7.
- **Where:** devcontainer.
- **Action (manual, read-only):** run every command of [Verification Commands](#verification-commands) and keep the output.
- **Expected:** `ns5` and `ns6.kasserver.com` answer the A record with `flags: qr aa` and TTL 7200; `NS do.sommerfeld.app` at `ns5` returns the wildcard CNAME; `ns1`, `ns2` and `ns3.digitalocean.com` answer the A record with `aa` and TTL 300, and the CAA record; public resolvers return `129.212.195.118`, and the wildcard CNAME for `NS` and `CAA do.sommerfeld.app`; `+trace` ends at `ns5` or `ns6.kasserver.com`; HTTPS as in M12.
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** none needed. If DigitalOcean answers wrong, fix it in OpenTofu first ([R2](#r2-wrong-record)).

### M8a: Allow ZeroSSL in the CAA Records

- **When:** after M8, before M10.
- **Where:** devcontainer.
- **Why:** the Caddyfile configures no issuer, so Caddy falls back from Let's Encrypt to ZeroSSL. `CAA 0 issue "letsencrypt.org"` alone would refuse that fallback once `do` is delegated. ZeroSSL's CAA identifier is `sectigo.com`.
- **Action (manual, OpenTofu applies):** `task cloud:digital-ocean:opentofu:plan`, then `task cloud:digital-ocean:opentofu:apply` and answer `yes` only when the plan is exactly this:
    - `digitalocean_record.caa has moved to digitalocean_record.caa["letsencrypt.org"]`, unchanged (the `moved` block in `dns.tf`);
    - `digitalocean_record.caa["sectigo.com"] will be created`;
    - `Plan: 1 to add, 0 to change, 0 to destroy.`
- **Verify:** a second plan says `No changes.`, and `task cloud:dns:check -- +norec @ns1.digitalocean.com do.sommerfeld.app CAA` returns two records, `0 issue "letsencrypt.org"` and `0 issue "sectigo.com"`, with `aa`.
- **Repeat-safe:** yes. **Outage risk:** none, the zone is not public yet. **Rollback:** remove `"sectigo.com"` from `local.dns_caa_issuers` in `dns.tf`, then plan and apply: the plan destroys only `digitalocean_record.caa["sectigo.com"]`. Never revert the `for_each` or remove the `moved` block: without a reverse move, the plan would destroy and recreate the Let's Encrypt record. Without the `moved` block, `tofu state mv 'digitalocean_record.caa' 'digitalocean_record.caa["letsencrypt.org"]'` does the same; never let the plan destroy and recreate the Let's Encrypt record.

### M9: Confirm DNSSEC Is Off

- **When:** before M10.
- **Where:** KAS → Tools → DNS-Einstellungen (look for a DNSSEC option), and the devcontainer.
- **Action (manual, read-only):** confirm DNSSEC is off for `sommerfeld.app`. Do not enable it during the migration.
- **Verify:** `curl -s 'https://dns.google/resolve?name=sommerfeld.app&type=DS' | python3 -m json.tool` has no `Answer` (true on 2026-10-22).
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** none needed.

### M10: Add the NS Records

- **When:** after M8a and M9.
- **Where:** KAS → Tools → DNS-Einstellungen → `sommerfeld.app` → "Neuen DNS-Eintrag".
- **Action (manual):** create the three records from [Delegation](#delegation): Name `do`, Type `NS`, Prio `0`, Data `ns1.digitalocean.com.`, then the same with `ns2.digitalocean.com.` and `ns3.digitalocean.com.`. **Keep the trailing dot.** Leave the A record `fantasy-hockey.prod.do` in place. Note the time (`date -u`): M13 counts from it. all-inkl says changes take up to 3 to 4 hours.
- **If the KAS refuses the NS records** (for example because the A record exists below `do`): stop. Do not delete the A record to make room, that opens a window in which the name may resolve to the wildcard. Re-plan.
- **Repeat-safe:** yes, the same records. **Outage risk:** none, both sides answer the same IP. **Rollback:** [R1](#r1-broken-delegation).

### M11: Check the Delegation

- **When:** after M10, repeat until green.
- **Where:** devcontainer.
- **Action (manual, read-only):** the [authoritative KAS checks](#authoritative-kas), the [trace](#trace) and the [public DNS checks](#public-dns).
- **Expected:** `ns5` and `ns6.kasserver.com` return a referral: `flags: qr` without `aa`, `ANSWER: 0`, three NS records `ns1`/`ns2`/`ns3.digitalocean.com.` in the authority section. `+trace` ends with `Received … from … (nsN.digitalocean.com)`. Google and Cloudflare return the DigitalOcean nameservers for `NS do.sommerfeld.app` and the reserved IP for the app name. Public NS can lag by up to 7200 s while a resolver still caches the wildcard answer.
- **If the KAS still answers the A record with `aa`:** it serves the occluded record, and the delegation is not effective for that name. The old A record keeps the service up. Open a support ticket with all-inkl before M14.
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** still red 4 hours after M10 → [R1](#r1-broken-delegation).

### M12: Check HTTPS

- **When:** after M11 is green.
- **Where:** outside the home network (mobile data) for the browser and `curl`, and the devcontainer.
- **Action (manual, read-only):** the [HTTPS checks](#https) and the CAA query from the [public DNS checks](#public-dns).
- **Expected:** `302` to `/login`, `/login` `200`, `http://` `308` to `https://`, `/metrics` `404`; certificate issuer Let's Encrypt or, after a renewal through Caddy's fallback, ZeroSSL (`O=ZeroSSL`, a Sectigo CA), and expiry `Jan 13 18:13:07 2027 GMT` or later; CAA `0 issue "letsencrypt.org"` and `0 issue "sectigo.com"`.
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** red → [R1](#r1-broken-delegation). A ZeroSSL issuer alone is not red and no reason for R1: M8a allows it on purpose.

### M13: Wait Two TTLs

- **When:** after M12.
- **Where:** calendar, then the devcontainer and outside the home network.
- **Action (manual):** wait at least 4 hours (2 × the KAS TTL of 7200 s) after M10, ideally 24 hours. Then repeat M11 and M12 once.
- **Why:** by then every resolver has expired the KAS answers and asks DigitalOcean.
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** red → [R1](#r1-broken-delegation).

### M14: Delete the Obsolete KAS A Record

- **When:** only after M13's wait has passed and M12 has passed.
- **Where:** KAS → Tools → DNS-Einstellungen → `sommerfeld.app`.
- **Action (manual):** delete the A record `fantasy-hockey.prod.do` (value `129.212.195.118`). Touch nothing else.
- **Why:** the delegation occludes it, and a stale copy at the KAS would mislead the next operator.
- **Verify:** `ns5.kasserver.com` still refers; Google and Cloudflare still return the reserved IP; the KAS list equals the M7 baseline minus the A record plus the three NS records.
- **Repeat-safe:** yes. **Outage risk:** only if the delegation is broken, which M11 to M13 excluded. **Rollback:** [R3](#r3-failure-after-the-a-record-is-gone).

### M15: Deploy Once

- **When:** after M14. Optional.
- **Where:** devcontainer (vault password).
- **Action (manual):** `task cloud:digital-ocean:ansible:deploy-fantasy-hockey`.
- **Expected:** the task "Stop when the domain does not resolve to the reserved IP" passes: the droplet's resolver sees the DigitalOcean answer. The play may restart nothing.
- **Repeat-safe:** yes, idempotent. **Outage risk:** none. **Rollback:** none needed.

### M16: Report and Close

- **When:** after M14 (and M15, if run).
- **Where:** devcontainer.
- **Action (manual):** report the M7 to M15 outputs with their `date -u` timestamps, so the dates go into [Domain](domain.md#history). Close Epic 7 retro items 26 (CAA, now in the DigitalOcean zone) and 27 (decided: yes) in `_bmad-output/implementation-artifacts/sprint-status.yaml`, or ask the agent to.
- **Repeat-safe:** yes. **Outage risk:** none. **Rollback:** none needed.

## Verification Commands

Ask authoritative servers without recursion **and** at least two independent public resolvers. One resolver is never enough: the home router (Fritz!Box) and every resolver cache old answers. `task cloud:dns:check` runs `dig` in a container (see [DNS Zone](dns-zone.md#checks)); everything after `--` goes to `dig`.

### Authoritative KAS

```bash
task cloud:dns:check -- +norec @ns5.kasserver.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns6.kasserver.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns5.kasserver.com do.sommerfeld.app NS
```

Before M10: `flags: qr aa`, the A record with TTL 7200, and the wildcard CNAME `w00f8074.kasserver.com.` for `NS do.sommerfeld.app`. After M10: a referral, `flags: qr` without `aa`, `ANSWER: 0`, and in the `AUTHORITY SECTION` the three records `do.sommerfeld.app. 7200 IN NS nsN.digitalocean.com.`.

### Authoritative DigitalOcean

```bash
task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns2.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns3.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns1.digitalocean.com do.sommerfeld.app CAA
```

Always `flags: qr aa`, the reserved IP from `tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses` with TTL 300, and after M8a the two CAA records.

### Trace

```bash
task cloud:dns:check -- +trace fantasy-hockey.prod.do.sommerfeld.app A | grep -E 'Received|IN.A'
```

The last `Received … from` line names the server that answered: `ns5` or `ns6.kasserver.com` before M10, `ns1`, `ns2` or `ns3.digitalocean.com` after it. `+trace` starts at the root servers, so it bypasses every cache.

### Public DNS

```bash
for q in 'do.sommerfeld.app&type=NS' 'fantasy-hockey.prod.do.sommerfeld.app&type=A' 'do.sommerfeld.app&type=CAA'; do
  curl -s "https://dns.google/resolve?name=$q" | python3 -m json.tool
  curl -s -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$q" | python3 -m json.tool
done
```

After the delegation, both resolvers return `ns1`/`ns2`/`ns3.digitalocean.com.` (type 2), exactly one A record with the reserved IP (type 1), and the two CAA records (type 257). A CNAME to `w00f8074.kasserver.com.` means the resolver still caches the wildcard answer (see [Cached Wildcard](#cached-wildcard)).

Names outside `do` must keep their M7 answers, for example:

```bash
for q in 'sommerfeld.app&type=A' 'www.sommerfeld.app&type=A' 'sommerfeld.app&type=MX' 'sommerfeld.app&type=NS'; do
  curl -s "https://dns.google/resolve?name=$q" | python3 -m json.tool
done
```

### HTTPS

From outside the home network (mobile data) and from the devcontainer:

```bash
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://fantasy-hockey.prod.do.sommerfeld.app/
curl -s -o /dev/null -w '%{http_code}\n' https://fantasy-hockey.prod.do.sommerfeld.app/login
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' http://fantasy-hockey.prod.do.sommerfeld.app/
curl -s -o /dev/null -w '%{http_code}\n' https://fantasy-hockey.prod.do.sommerfeld.app/metrics
echo | openssl s_client -connect fantasy-hockey.prod.do.sommerfeld.app:443 -servername fantasy-hockey.prod.do.sommerfeld.app 2>/dev/null | openssl x509 -noout -issuer -enddate
```

Expected: `302 https://…/login`, `200`, `308 https://…/`, `404`, `issuer=C=US, O=Let's Encrypt, CN=…` and `notAfter=Jan 13 18:13:07 2027 GMT` or later. After a renewal the issuer may be ZeroSSL (`O=ZeroSSL`, a Sectigo CA), Caddy's fallback that M8a allows: that is green, not a reason for [R1](#r1-broken-delegation).

## Rollback

Never delete the DigitalOcean zone as part of a rollback, and never run `tofu destroy`, a `-target` destroy or a `force`. The zone keeps `prevent_destroy` until every cache of the delegation has expired, so a resolver that still holds the DigitalOcean NS records keeps getting correct answers.

### R1: Broken Delegation

After M10, before M14. Who: operator (manual). Where: KAS.

1. Delete the three NS records `do` in the KAS. The old A record still exists, so the KAS answers again at once.
2. Resolvers that cached the DigitalOcean NS records keep asking DigitalOcean until the NS TTL expires (up to 7200 s for the parent's NS records), and DigitalOcean still answers correctly. **Keep the DigitalOcean zone.**
3. Check with the [authoritative KAS checks](#authoritative-kas): `aa` and the A record again.

### R2: Wrong Record

Any time. Who: operator (manual), OpenTofu applies. Where: devcontainer.

Fix `dns.tf` (or the droplet map), then plan, review and apply (see [Plan and Review](dns-zone.md#plan-and-review)). The fix is visible after the record TTL (300 s); HTTPS can fail until then, and Caddy retries its renewals. For an urgent fix before review, the DigitalOcean control panel works too, but the next plan shows the drift and must be reconciled in code. If the zone was deleted outside OpenTofu, `apply` recreates it with the same nameservers, and the KAS needs no change.

To undo M8a, remove `"sectigo.com"` from `local.dns_caa_issuers` and apply: the plan destroys only `digitalocean_record.caa["sectigo.com"]`. Never revert the `for_each` or the `moved` block: without a reverse move, the plan would destroy and recreate the Let's Encrypt record.

### R3: Failure After the A Record Is Gone

After M14. Who: operator (manual). Where: KAS.

Recreate the A record in the KAS (Name `fantasy-hockey.prod.do`, Type `A`, Data the reserved IP from `tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses`, TTL 7200), then do [R1](#r1-broken-delegation).

### R4: State Lost or Corrupt

Any time. Who: operator (manual). Where: devcontainer.

Restore the newest state backup, for example Story 8.1's M3 (`~/tfstate-backups/terraform.tfstate.pre-dns-*`). That backup was taken before the DNS apply, so it has no zone and no records: after restoring it, or when there is no backup at all, import the zone and every record. The import addresses must match the current keys in `dns.tf`: one `digitalocean_record.a["<name>"]` per name in `tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_records` (name relative to the zone) and one `digitalocean_record.caa["<issuer>"]` per entry of `local.dns_caa_issuers`. The record IDs come from `doctl compute domain records list do.sommerfeld.app`. With today's keys:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu import 'digitalocean_domain.this' do.sommerfeld.app
tofu -chdir=configs-cloud/digital-ocean/opentofu import 'digitalocean_record.a["fantasy-hockey.prod"]' do.sommerfeld.app,<id>
tofu -chdir=configs-cloud/digital-ocean/opentofu import 'digitalocean_record.caa["letsencrypt.org"]' do.sommerfeld.app,<id>
tofu -chdir=configs-cloud/digital-ocean/opentofu import 'digitalocean_record.caa["sectigo.com"]' do.sommerfeld.app,<id>
```

Then a plan must show no create for the imported resources. The public answers do not change during R4: the zone at DigitalOcean is untouched.

## Troubleshooting

### Lame Delegation

The KAS refers `do` to DigitalOcean, but `task cloud:dns:check -- +norec @ns1.digitalocean.com do.sommerfeld.app SOA` returns `status: REFUSED`: DigitalOcean serves no zone of that name, and public resolvers return `SERVFAIL`. The zone was deleted outside OpenTofu. Run a plan and apply it to recreate the zone ([R2](#r2-wrong-record)), or do [R1](#r1-broken-delegation) (or [R3](#r3-failure-after-the-a-record-is-gone) after M14) until it is back.

### Cached Wildcard

A resolver that asked for `do.sommerfeld.app` or a name below it before M10 caches the wildcard CNAME `w00f8074.kasserver.com` for up to 7200 s. The app name itself keeps working during that time through the old A record, which is why it stays until M14. Wait; `+trace` shows the current truth without caches.

### Referral Without Glue

The KAS referral has no `ADDITIONAL` section with addresses for `ns1`–`ns3.digitalocean.com`. That is correct: the nameservers live under `digitalocean.com`, outside the delegated zone, so resolvers look them up separately and no glue records are needed.

### Occluded A Record

If the KAS still answers `fantasy-hockey.prod.do` with `aa` after M10, it serves the record below the delegation point (occluded data). The delegation is then effective for every other name but not this one until M14. Ask all-inkl support before M14, then check again right after M14 with the [authoritative KAS checks](#authoritative-kas).

### DNSSEC

`sommerfeld.app` is not signed (no DS at `.app`, checked 2026-10-22). If DNSSEC is enabled at the KAS later, the delegation to the unsigned DigitalOcean zone stays valid as an insecure delegation, provided the KAS signs the NS records with an NSEC or NSEC3 proof that `do` has no DS. Recheck then: `task cloud:dns:check -- +dnssec +norec @ns5.kasserver.com do.sommerfeld.app DS` must return no DS record, and Google must still resolve the app name. Never add a DS record for `do`: DigitalOcean cannot sign the zone.

### CAA

Once `do` is delegated, every CAA lookup for a name under `do` stops at `do.sommerfeld.app`, where the DigitalOcean zone answers `0 issue "letsencrypt.org"` and `0 issue "sectigo.com"` (ZeroSSL, Caddy's fallback issuer). The wildcard CNAME no longer answers CAA lookups. A certificate authority other than these two is refused. To add one, add its CAA identifier to `local.dns_caa_issuers` in `dns.tf`.

## Sequence

Elements marked `<<manual>>` and every message labelled "manual" are done by hand by the operator; nothing automates the KAS.

```kroki-plantuml
@startuml
skinparam sequenceMessageAlign center
skinparam participant<<manual>> {
  BackgroundColor #FFF4E0
  BorderColor #C77700
}
skinparam actor<<manual>> {
  BackgroundColor #FFF4E0
  BorderColor #C77700
}

actor "Operator" as operator <<manual>>
participant "KAS\n(all-inkl.com)" as kas <<manual>>
participant "Parent zone\nsommerfeld.app\nns5/ns6.kasserver.com" as parent
participant "OpenTofu" as tofu
participant "DigitalOcean API" as api
participant "DigitalOcean DNS\nns1-3.digitalocean.com" as dodns
participant "Public resolvers\n(Google, Cloudflare)" as resolvers
participant "Droplet\n(Caddy)" as droplet

group Inventory and preparation
  operator -> kas : M7 list every record and subdomain (manual, read-only)
  kas --> operator : records and TTLs; only A fantasy-hockey.prod.do under do
  operator -> parent : M8 +norec A (baseline)
  parent --> operator : aa, A reserved IP, TTL 7200
  operator -> resolvers : M8 DoH NS, A, CAA (baseline)
  resolvers --> operator : wildcard CNAME for do, A reserved IP
  operator -> tofu : M8a plan, review, apply
  tofu -> api : create CAA sectigo.com\n(letsencrypt.org moved, unchanged)
  api -> dodns : two CAA records
  operator -> kas : M9 confirm DNSSEC is off (manual, read-only)
end

group Zone created and validated (Story 8.1, reference only)
  operator -> tofu : M4 plan, review, apply
  tofu -> api : create zone, A and CAA records
  api -> dodns : serve do.sommerfeld.app
  operator -> dodns : M5 +norec A, CAA
  dodns --> operator : aa, reserved IP, CAA
  alt validation fails
    operator -> tofu : R2 fix dns.tf, plan, apply
  end
end

group NS delegation at the KAS
  operator -> kas : M10 create NS do -> ns1/ns2/ns3.digitalocean.com. (manual)
  kas -> parent : publish NS do x3\n(A fantasy-hockey.prod.do stays)
end

group Import: none expected
  alt M2 found a zone or the state is lost
    operator -> tofu : R4 restore the backup or tofu import
    tofu -> api : read the zone and records
  else no zone (2026-10-22: none)
    note over tofu : nothing to import
  end
end

group DNS verification
  operator -> parent : M11 +norec @ns5/@ns6 A
  parent --> operator : referral: NS x3, no aa
  operator -> resolvers : M11 DoH NS do.sommerfeld.app, A
  resolvers -> parent : fantasy-hockey.prod.do.sommerfeld.app?
  parent --> resolvers : referral to DigitalOcean
  resolvers -> dodns : fantasy-hockey.prod.do.sommerfeld.app?
  dodns --> resolvers : aa, reserved IP
  resolvers --> operator : DigitalOcean NS, reserved IP
  alt validation fails (still red 4 h after M10)
    operator -> kas : R1 delete the three NS records (manual)
  end
end

group HTTPS verification
  operator -> droplet : M12 https /, /login, http://, /metrics, openssl\n(outside the home network)
  droplet --> operator : 302, 200, 308, 404; same certificate
  operator -> resolvers : M12 DoH CAA do.sommerfeld.app
  resolvers --> operator : letsencrypt.org, sectigo.com
  alt validation fails
    operator -> kas : R1 delete the three NS records (manual)
  end
end

group Wait 2 x TTL
  ... at least 4 h after M10 (2 x 7200 s), ideally 24 h ...
  operator -> resolvers : M13 repeat M11 and M12
  alt validation fails
    operator -> kas : R1 delete the three NS records (manual)
  end
end

group Remove the obsolete A record
  operator -> kas : M14 delete A fantasy-hockey.prod.do (manual)
  kas -> parent : A record gone, NS do x3 stay
end

group Final checks
  operator -> parent : +norec @ns5/@ns6 A
  parent --> operator : still a referral
  operator -> resolvers : DoH A, NS, CAA
  resolvers --> operator : reserved IP from DigitalOcean
  operator -> droplet : M15 deploy (optional, vault password)
  droplet -> resolvers : DNS guard: getent ahostsv4
  resolvers --> droplet : exactly the reserved IP
  alt validation fails
    operator -> kas : R3 recreate the A record, then R1 (manual)
  end
end
@enduml
```

The same runbook fits another provider label from [Domain Naming](../domain-naming.md) (for example `linode`), with that provider's nameservers in place of DigitalOcean's.
