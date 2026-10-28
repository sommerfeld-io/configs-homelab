# DNS Zone

OpenTofu declares the DigitalOcean DNS zone `do.sommerfeld.app` and every record in it, in `configs-cloud/digital-ocean/opentofu/dns.tf`. The zone lives in the same root module and state as the droplets. Its records are derived from the `droplets` map, so a new app with a reserved IP gets its hostname in the same apply that creates the droplet.

`sommerfeld.app` stays at all-inkl.com. Its nameservers (`ns5`/`ns6.kasserver.com`) delegate `do` to `ns1`/`ns2`/`ns3.digitalocean.com` with three NS records, set by hand in the KAS, so resolvers ask DigitalOcean for every name at or below `do.sommerfeld.app`. The NS records, the migration from the hand-made KAS record and the rollback are described in [DNS Delegation](dns-delegation.md).

## Architecture

Two zones, two providers:

| Zone                | Hosted at                                                   | Authoritative for                                                          | Managed by                  |
|---------------------|-------------------------------------------------------------|----------------------------------------------------------------------------|-----------------------------|
| `sommerfeld.app`    | all-inkl.com (registrar and DNS, `ns5`/`ns6.kasserver.com`) | `sommerfeld.app` and every name outside `do`, plus the NS records for `do` | by hand in the KAS (manual) |
| `do.sommerfeld.app` | DigitalOcean DNS (`ns1`/`ns2`/`ns3.digitalocean.com`)       | `do.sommerfeld.app` and every name below it, delegated by the KAS          | OpenTofu (`dns.tf`)         |

```kroki-plantuml
@startuml
skinparam card<<digitalocean>> {
  BorderColor #0969DA
  BorderThickness 2
}
skinparam card<<allinkl>> {
  BorderColor #BF3989
  BorderThickness 2
}
hide <<digitalocean>> stereotype
hide <<allinkl>> stereotype
skinparam defaultTextAlignment center
skinparam rectangle<<manual>> {
  BackgroundColor #FFF4E0
  BorderColor #C77700
}
skinparam node<<manual>> {
  BackgroundColor #FFF4E0
  BorderColor #C77700
}

actor "Client\n(browser)" as client
node "Recursive resolver\n(ISP, Google, Cloudflare)" as resolver

cloud ".app registry" as registry {
  rectangle "TLD zone app.\nNS sommerfeld.app -> ns5/ns6.kasserver.com" as tld
}

card "all-inkl.com" as allinkl <<allinkl>> {
  rectangle "Registrar and KAS" <<manual>> as kas
  rectangle "Zone sommerfeld.app\nns5/ns6.kasserver.com\nauthoritative for sommerfeld.app" as parent
  rectangle "NS do -> ns1/ns2/ns3.digitalocean.com\nmanual in the KAS (Story 8.2)" <<manual>> as delegation
}

node "Operator devcontainer" as devcontainer {
  component "OpenTofu\ndns.tf" as tofu
}

card "DigitalOcean" as digitalocean <<digitalocean>> {
  component "DigitalOcean API" as api
  rectangle "Zone do.sommerfeld.app\nns1/ns2/ns3.digitalocean.com\nauthoritative for do.sommerfeld.app and below" as zone
  rectangle "A fantasy-hockey.prod  TTL 300\nCAA @ 0 issue letsencrypt.org, sectigo.com  TTL 3600" as records
  component "Reserved IP\n(prevent_destroy)" as reservedip
  node "Droplet prod-fantasy-hockey\nCaddy :443" as droplet
}

kas --> parent : edits by hand
parent --> delegation : refers "do" to
delegation --> zone : delegates
tld --> parent : delegates sommerfeld.app

tofu --> api : plan, apply\nDIGITALOCEAN_ACCESS_TOKEN (domain scope)
api --> zone : manages
zone --> records
records --> reservedip : value = reserved IP
reservedip --> droplet : assigned to

client --> resolver : 1. fantasy-hockey.prod.do.sommerfeld.app?
resolver --> tld : 2. who serves sommerfeld.app?
resolver --> parent : 3. who serves do.sommerfeld.app?\nreferral to DigitalOcean
resolver --> zone : 4. A record (aa)
client --> reservedip : 5. HTTPS :443 to the reserved IP
@enduml
```

Elements with the orange `<<manual>>` stereotype are changed by hand in the KAS, never by OpenTofu.

## Records

### Derived Records

Every droplet in the `droplets` map with `reserved_ip = true` gets one A record:

| Name (relative to the zone) | Type | Value                                           | TTL |
|-----------------------------|------|-------------------------------------------------|-----|
| `<key>.<stage>`             | `A`  | `digitalocean_reserved_ip.this[key].ip_address` | 300 |

`<key>` is the droplet's key in the `droplets` map and `<stage>` its `stage`, so the entry `fantasy-hockey` with `stage = "prod"` gives `fantasy-hockey.prod.do.sommerfeld.app`, the hostname pattern from [Domain Naming](../domain-naming.md). The value references the reserved IP resource. No IP is copied into the code. A droplet with `reserved_ip = false` gets no record and has no public name.

The record name relative to the zone (`fantasy-hockey.prod`) is also the `for_each` key of `digitalocean_record.a`. It never depends on a value that is only known after apply, so an address change is an in-place update (`~ value`), never a replacement.

Read the records after an apply with:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_records
tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_zone
```

### Aliases

The optional droplet option `dns_aliases` adds more names for the same droplet. Each alias is a name relative to the zone and gets an A record on the droplet's reserved IP:

```hcl
    fantasy-hockey = {
      stage       = "prod"
      # ...
      reserved_ip = true
      dns_aliases = ["hockey.prod"]
    }
```

Every alias must end in `.<stage>` of its droplet, and the droplet needs `reserved_ip = true`. Otherwise the plan fails with a precondition error. An alias creates the DNS record only: Caddy serves only the derived name, so an alias does not answer over HTTPS until a separate Caddy change adds it.

### External Records

`local.dns_external_records` in `dns.tf` maps names to IPv4 addresses that this configuration does not manage. These are the only literal IPs allowed in `dns.tf`. Only hosts the operator controls may be listed, each with a comment naming the owner of the address:

```hcl
  dns_external_records = {
    "status.prod" = "203.0.113.10" # owner: <who runs this host>
  }
```

The map is empty today. A value that is not an IPv4 address fails the plan.

### Unique Names

The three sources (derived names, aliases, external records) share one namespace. A name that two sources produce, or one alias listed twice, fails the plan with a precondition error on `digitalocean_domain.this` that lists the duplicate names.

### TTL and CAA

- A records have a TTL of 300 s: a wrong record heals five minutes after the fix is applied.
- The zone apex has one `CAA 0 issue` record per entry of `local.dns_caa_issuers`, each with a TTL of 3600 s: `letsencrypt.org` and `sectigo.com`. Only the issuers Caddy uses may issue certificates for `do.sommerfeld.app` and every name below it: Caddy configures no issuer, so it tries Let's Encrypt first and falls back to ZeroSSL, whose CAA identifier is `sectigo.com`. Because `do` is delegated, every CAA lookup for a name under `do` stops here; the parent zone's wildcard never answers it. In `dns.tf` each value is written with a trailing dot (`letsencrypt.org.`), because the provider reads it back that way; without the dot every plan would show a change. DigitalOcean serves it without the dot (`0 issue "letsencrypt.org"`, checked 2026-10-22).
- `digitalocean_record.caa` is keyed by issuer. Story 8.1 created the Let's Encrypt record as a single resource; a `moved` block in `dns.tf` moves it to `digitalocean_record.caa["letsencrypt.org"]` without replacing it.
- There is no AAAA record (the reserved IP is IPv4 only), no wildcard (an undeclared name returns NXDOMAIN, and the deploy's DNS guard stops on a name that resolves to nothing) and no DNSSEC (DigitalOcean DNS cannot sign zones).
- The SOA and NS records at the apex are created by DigitalOcean and stay unmanaged. Never declare them.

## How-Tos

Every how-to ends with the steps in [Plan and Review](#plan-and-review). None of them needs a KAS change: the delegation covers every name under `do`.

### Add an App Hostname

Add a droplet entry with `reserved_ip = true` to `droplets.tf` (see [Droplet](droplet.md#add-a-droplet)). The plan creates the droplet, the reserved IP, the assignment and the A record `<key>.<stage>` in one apply. The first deploy waits until the name resolves; a resolver that asked for the name before the record existed caches the NXDOMAIN for up to the zone's SOA minimum (read it after the first apply with `task cloud:dns:check -- +norec @ns1.digitalocean.com SOA do.sommerfeld.app`).

### Update a Target IP

The A record follows the reserved IP. A new reserved IP (a deliberate replacement after lifting `prevent_destroy`, or a region change) shows up in the plan as `~ value` on `digitalocean_record.a["<key>.<stage>"]`, in place. Resolvers keep the old address for the rest of the TTL (up to 300 s). For an external record, change its value in `dns_external_records`.

### Remove a Hostname

The record goes in the same apply as the droplet: removing the droplet entry removes its record. Never leave a record on a released reserved IP: DigitalOcean can give the address to another customer, who could then serve content under the name. The reserved IP and the volume have `prevent_destroy`, so removing a droplet entry fails the plan until they are handled deliberately (see [Droplet](droplet.md#reserved-ip-and-volume)). To remove only an alias or an external name, delete it from `dns_aliases` or `dns_external_records`.

### Recreated Droplet

A [Replacement](replacement.md) changes no record. The record references the reserved IP, not the droplet, and the reserved IP survives the replacement. The plan shows the droplet and the assignment as `-/+` and no change to any `digitalocean_record`.

### Move an App to Another Droplet

The record name comes only from the map key, the `stage` and `dns_aliases`. Moving the app to another droplet entry, or changing its key or `stage`, changes the record:

- a new name: the old record is destroyed (`-`) and the new one created (`+`);
- the same name on a new reserved IP: `~ value` in place.

The deploy's DNS guard stops the deploy until the new answer resolves to the new reserved IP on the droplet.

### Point a Name at an External IP

Add the name and the address to `dns_external_records` with a comment naming the owner. The plan creates an A record with the literal value. The name must not collide with a derived name or an alias.

### Same App in Another Stage

The droplet name and the hostname both use the map key, and the key is unique per droplet. A second stage of the same app therefore needs its own key, for example `fantasy-hockey-test` with `stage = "test"`, which derives `fantasy-hockey-test.test.do.sommerfeld.app`. Getting `fantasy-hockey.test` instead needs an optional `app` field on the droplet entry and the same change in the deploy playbook's derivation (`inventory_hostname.split('-', 1)`). That decision is still open. Until it is made, only `prod` exists, and the key is the app name.

## Plan and Review

Run from the repository root with `DIGITALOCEAN_ACCESS_TOKEN` set:

1. `task cloud:digital-ocean:opentofu:init`, after provider changes or in a fresh clone.
2. `task opentofu:validate`: syntax and references of every OpenTofu root, offline once initialized.
3. Write the plan to a file and list every action:

    ```bash
    tofu -chdir=configs-cloud/digital-ocean/opentofu plan -out=dns.tfplan
    tofu -chdir=configs-cloud/digital-ocean/opentofu show -json dns.tfplan \
      | jq -r '.resource_changes[] | select(.change.actions != ["no-op"]) | "\(.change.actions|join(",")) \(.address)"'
    ```

4. Read the actions. A DNS change creates, updates or deletes `digitalocean_record.*` only, plus an update of `digitalocean_project_resources.this` when the zone itself is new. Any `delete` or replacement you did not intend means stop.
5. Apply exactly the reviewed plan (manual, operator): `tofu -chdir=configs-cloud/digital-ocean/opentofu apply dns.tfplan`. Then delete `dns.tfplan`: it can contain state data.
6. Plan again: `tofu -chdir=configs-cloud/digital-ocean/opentofu plan -detailed-exitcode` must print `No changes.` and exit 0. Exit code 2 means there are changes; a change right after an apply is a perpetual diff (see [Troubleshooting](#troubleshooting)).

Before the first apply that adds the zone, back up the state outside the repository. `.gitignore` matches `*.tfstate`, `*.tfstate.*` and `*.tfplan`, but a backup under another name inside the repository could still be committed:

```bash
mkdir -p ~/tfstate-backups
cp configs-cloud/digital-ocean/opentofu/terraform.tfstate ~/tfstate-backups/terraform.tfstate.pre-dns-$(date +%Y%m%d%H%M)
```

## Import an Existing Zone or Record

If `doctl compute domain list` shows `do.sommerfeld.app` before the first apply, import it instead of creating it twice:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu import 'digitalocean_domain.this' do.sommerfeld.app
doctl compute domain records list do.sommerfeld.app
tofu -chdir=configs-cloud/digital-ocean/opentofu import 'digitalocean_record.a["fantasy-hockey.prod"]' do.sommerfeld.app,<record-id>
```

Then run the plan again: it must not show a create for the imported resources. The KAS records cannot be imported, because they belong to another provider; they are recreated in the DigitalOcean zone. On 2026-10-22 the account had no zone (`doctl compute domain list` returned an empty list).

## Checks

The devcontainer has no `dig`, so `task cloud:dns:check` runs `dig` in a pinned container (`nicolaka/netshoot`, service `dns-check` in `docker-compose.yml`). Everything after `--` goes to `dig`. Ask the DigitalOcean nameservers directly, without recursion:

```bash
task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns2.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns3.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A
task cloud:dns:check -- +norec @ns1.digitalocean.com do.sommerfeld.app CAA
task cloud:dns:check -- +norec @ns1.digitalocean.com nothing-here.prod.do.sommerfeld.app A
```

Expected after the apply:

- the `flags:` line contains `aa` (authoritative answer);
- the A answers are the reserved IP from `tofu -chdir=configs-cloud/digital-ocean/opentofu output reserved_ip_addresses`, the same on all three nameservers;
- the CAA answers are `0 issue "letsencrypt.org"` and `0 issue "sectigo.com"`;
- the undeclared name returns `status: NXDOMAIN`.

`dns.tf` writes the CAA values with a trailing dot (`letsencrypt.org.`); DigitalOcean serves them without it (`0 issue "letsencrypt.org"`, Story 8.1 M5, 2026-10-22), which is what the certificate authorities match.

Before the zone exists, `ns1.digitalocean.com` answers `status: REFUSED`: it serves no zone of that name.

Public resolvers get the same answers through the delegation. Check them, the KAS referral and `+trace` with the commands in [DNS Delegation](dns-delegation.md#verification-commands).

## Troubleshooting

### NXDOMAIN

- From `ns1.digitalocean.com`: the name is not declared. Compare it with `tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_records`; check the key, the `stage` and `reserved_ip = true`.
- From a public resolver: a resolver that asked before the record existed caches the NXDOMAIN for up to the SOA minimum of the zone. Wait, or ask `ns1.digitalocean.com` to confirm the record exists.

### The Old all-inkl Answer

A CNAME to `w00f8074.kasserver.com` for a name under `do` comes from the parent zone's wildcard, cached from before the delegation, for up to the KAS TTL of 7200 s. If `+trace` also ends at a `kasserver.com` nameserver, the NS records for `do` are missing in the KAS (see [DNS Delegation](dns-delegation.md#troubleshooting)).

### Perpetual Diff

A second plan right after an apply must say `No changes.`. If it shows the same `~` again, the configured value differs from what the provider reads back. Typical causes are a missing trailing dot on a CAA, CNAME, MX, NS or SRV value, or a TTL that DigitalOcean changed (it warns "digitalocean_record TTL changed"). Normalize the value in `dns.tf` until the second plan is clean.

### 403 From the API

Without the `domain` scope, `tofu apply` fails with 403 when it creates the zone or a record, and `tofu plan` (its refresh) fails too once the zone is in the state. `doctl compute domain list` fails with 403 as well. A plan before the first apply only plans creates and does not call the domain API, so it does not catch a missing scope. Add it with `create`, `read`, `update` and `delete` (see [API Token](api-token.md)).

## Recovery

- **A wrong record:** fix `dns.tf` (or the droplet map), plan, review and apply. The fix is visible after the TTL (300 s). A change made in the control panel shows up as drift in the next plan and must be reconciled in code.
- **The zone was deleted outside OpenTofu:** `prevent_destroy` only protects against OpenTofu. The next plan creates the zone and all records again; apply it. The NS hostnames are the same for every DigitalOcean zone, so the delegation in the KAS needs no change.
- **State lost or corrupt:** restore the backup from [Plan and Review](#plan-and-review), or import the zone and records as in [Import an Existing Zone or Record](#import-an-existing-zone-or-record).

## Automated and Manual Steps

| Step                                                    | Who                     | Where                                                                                          |
|---------------------------------------------------------|-------------------------|------------------------------------------------------------------------------------------------|
| Derive record names and values from the droplet map     | OpenTofu (automated)    | `dns.tf`                                                                                       |
| Check duplicate names, alias suffixes and external IPv4 | OpenTofu (automated)    | `tofu plan` (preconditions)                                                                    |
| Format, lint and validate `dns.tf`                      | `task lint` (automated) | devcontainer, pre-commit hook, CI (`lint-opentofu`, `validate-opentofu`)                       |
| Add the `domain` scope to the API token                 | operator (manual)       | DigitalOcean control panel                                                                     |
| Back up the state before the first DNS apply            | operator (manual)       | devcontainer                                                                                   |
| Review the plan and apply                               | operator (manual)       | devcontainer                                                                                   |
| Check the zone with `task cloud:dns:check`              | operator (manual)       | devcontainer                                                                                   |
| Check public resolution                                 | operator (manual)       | outside the home network (DoH, phone hotspot)                                                  |
| NS records for `do` in the parent zone                  | operator (manual)       | KAS at all-inkl.com ([DNS Delegation](dns-delegation.md))                                      |
| Remove the hand-made KAS A record (once, Story 8.2)     | operator (manual)       | KAS at all-inkl.com ([DNS Delegation](dns-delegation.md#m14-delete-the-obsolete-kas-a-record)) |

## Change Flow

```kroki-plantuml
@startuml
actor "Operator" as operator
participant "OpenTofu" as tofu
participant "DigitalOcean API" as api
participant "Reserved IP" as reservedip
participant "Droplet" as droplet
participant "DigitalOcean DNS" as dns
participant "Recursive resolver" as resolver
actor "Client" as client

group Droplet replaced
  == Infrastructure change ==
  operator -> tofu : plan (image change or -replace)
  tofu --> operator : droplet -/+, assignment -/+\nno digitalocean_record change
  operator -> tofu : apply (manual review)
  tofu -> api : destroy and create the droplet
  api -> droplet : new droplet
  tofu -> api : recreate the reserved IP assignment
  api -> reservedip : assign to the new droplet
  == DNS update ==
  note over dns : nothing to update:\nthe record references the reserved IP
  == Caching ==
  client -> resolver : fantasy-hockey.prod.do.sommerfeld.app?
  resolver --> client : same reserved IP (cached or fresh)
  client -> reservedip : HTTPS :443
  reservedip -> droplet : forwarded to the new droplet
end

group Reserved IP or target changed
  == Infrastructure change ==
  operator -> tofu : plan
  tofu --> operator : digitalocean_record.a["fantasy-hockey.prod"]\n~ value (in place)
  operator -> tofu : apply (manual review)
  tofu -> api : create the new reserved IP (prevent_destroy lifted)\nor change an external target in dns_external_records
  == DNS update ==
  tofu -> api : update the record value
  api -> dns : A record = new address
  == Caching ==
  client -> resolver : fantasy-hockey.prod.do.sommerfeld.app?
  resolver --> client : old address from the cache\n(until the TTL of 300 s expires)
  ... up to 300 s ...
  client -> resolver : fantasy-hockey.prod.do.sommerfeld.app?
  resolver -> dns : cache expired: ask again
  dns --> resolver : new address (aa)
  resolver --> client : new address
end
@enduml
```

The resolver reaches DigitalOcean DNS through the referral from the parent zone at all-inkl.com (see [DNS Delegation](dns-delegation.md)).
