---
title: 'Story 8.1: DigitalOcean DNS zone do.sommerfeld.app in OpenTofu'
type: 'refactor'
created: '2026-10-15'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-7-1-dns-record-for-the-droplet.md'
    - '{project-root}/_bmad-output/implementation-artifacts/epic-7-retro-2026-10-15.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-8-2-delegate-do-sommerfeld-app-and-retire-the-kas-record.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The only record under `do.sommerfeld.app`, the A record `fantasy-hockey.prod.do.sommerfeld.app` → `129.212.195.118`, was created by hand in the KAS of all-inkl.com (Story 7.1). OpenTofu already declares the reserved IP the record points at (`digitalocean_reserved_ip.this` in `configs-cloud/digital-ocean/opentofu/reserved-ips.tf`), but the record itself is outside the declaration. Each new app, stage, or reserved IP change needs a manual KAS edit that nobody reviews and that can drift from the state. Epic 7 deliberately kept DNS out of OpenTofu. The operator reversed that decision on 2026-10-15 (Epic 7 retro, action item 27).

**Approach:** OpenTofu declares a DigitalOcean DNS zone `do.sommerfeld.app` and its records in a new `dns.tf`, in the same root module and state as the droplets. Records come from the `droplets` map in `droplets.tf`: every droplet with `reserved_ip = true` gets the A record `<key>.<stage>.do.sommerfeld.app` → `digitalocean_reserved_ip.this[key].ip_address`, a resource reference rather than a copied IP. Two optional inputs cover the other cases. `dns_aliases` adds extra names per droplet, and `local.dns_external_records` maps names to IPs that this configuration does not manage. The zone apex gets `CAA 0 issue "letsencrypt.org"`. This story changes nothing public: the zone exists at DigitalOcean but is **not delegated**, so the KAS stays authoritative. The records are verified by querying `ns1.digitalocean.com` directly. Delegation and retiring the KAS record are Story 8.2.

**Decisions (proposed 2026-10-15, confirm before build):**

- **Delegation, not a nameserver move:** `sommerfeld.app` stays registered and hosted at all-inkl.com (`ns5`/`ns6.kasserver.com`), and every unrelated record stays there. Only `do.sommerfeld.app` is delegated to `ns1`/`ns2`/`ns3.digitalocean.com` with NS records in the KAS (Story 8.2). Creating the zone at DigitalOcean does **not** make DigitalOcean authoritative: until the NS records exist in the parent zone, resolvers never ask DigitalOcean.
- **Target is the reserved IP, never the droplet's own IPv4:** the reserved IP survives a droplet replacement (`prevent_destroy`), so a replacement changes no record. A droplet without a reserved IP gets no record. The deploy refuses such a droplet anyway (`deploy-fantasy-hockey.yml`, "Stop when the droplet has no reserved IP").
- **One zone for all stages:** the stage is a label in the name (`<app>.<stage>.do.sommerfeld.app`, `docs/cloud/domain-naming.md`), so `dev`, `test` and `prod` records share the one zone, root module and state. There are no OpenTofu workspaces and no zone per stage, matching the existing one-root layout.
- **Record TTL 300 s for A records, 3600 s for CAA:** a wrong A record heals five minutes after a fix. DigitalOcean DNS is free, and the query volume is negligible.
- **No wildcard in the new zone:** names that are not declared return NXDOMAIN instead of the all-inkl web host (`w00f8074.kasserver.com`). The deploy's DNS guard handles that: "resolves to nothing" stops the deploy.

## Boundaries & Constraints

**Always:**

- Put all DNS resources in `configs-cloud/digital-ocean/opentofu/dns.tf` and the new outputs in `outputs.tf`. Follow the file style of `reserved-ips.tf` and `volumes.tf`: `this`-style naming where it fits, a comment above each resource saying why, and `for_each` over a local map.
- Derive record names and values from `local.droplets` and resource attributes. The only literal IPs allowed are the values in `local.dns_external_records`, each with a comment naming the owner of the address.
- Use the record name relative to the zone as the `for_each` key (`fantasy-hockey.prod`). Keys must not depend on any value that is only known after apply. An IP change is then an in-place update (`~`), never a replacement.
- Give `digitalocean_domain` `prevent_destroy = true`. Deleting the zone deletes every record in it. Do not set `ip_address` on it: that argument creates an apex A record outside `for_each`.
- Fail the plan with a clear message, through `lifecycle.precondition` blocks on `digitalocean_domain.this`, when:
    - two sources produce the same record name (droplet-derived, `dns_aliases`, external);
    - an alias does not end in `.<stage>` of its droplet;
    - an external value is not an IPv4 address.
- Keep the provider pin (`digitalocean/digitalocean` `2.106.0`, `versions.tf`) and the lock file. Do not upgrade the provider in this story.
- Back up `terraform.tfstate` before the first apply that adds DNS resources, outside the repo (M3). `.gitignore` matches `*.tfstate` only, so a `terraform.tfstate.<suffix>` copy inside the repo would be committable.
- Update the docs and the diagrams in the same change. `task lint` passes.

**Never:**

- No NS record in the KAS, no change to `sommerfeld.app` or any other zone at all-inkl.com, no change to the registrar or the nameservers of `sommerfeld.app`. Story 8.2 does the delegation.
- The agent never runs `tofu apply`, `apply:yes` or `deploy:all`, and never changes the DigitalOcean token. The operator applies (Manual Tasks M3 and M4).
- No AAAA records (the reserved IP is IPv4 only), no DNSSEC (DigitalOcean DNS does not support it), no wildcard record.
- No new OpenTofu root, module, workspace or backend. Remote state is Story 6.2.
- No token, password or IP of a third party in the repo. An external record's IP is public data, but only a host the operator controls may be listed.
- No change to Caddy, the Caddyfile or the app. `dns_aliases` creates DNS records only. Serving an alias over HTTPS needs a separate Caddy change (out of scope).

## I/O & Edge-Case Matrix

| Scenario                     | Input / State                                                                             | Expected plan                                                                                                                                                  | Error Handling                                                                                                                                            |
|------------------------------|-------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| First apply                  | current `droplets` map, zone absent at DigitalOcean                                       | create `digitalocean_domain.this`, A `fantasy-hockey.prod`, CAA `@`; update in place `digitalocean_project_resources.this` (adds the domain URN); nothing else | zone already exists (M2 found it) → import first, see Design Notes                                                                                        |
| Second plan, nothing changed | same inputs                                                                               | `No changes.` (`tofu plan -detailed-exitcode` exits 0)                                                                                                         | a perpetual diff (e.g. CAA value with or without trailing dot, TTL) is a defect: normalize the value until the second plan is clean                       |
| Droplet replaced             | `-replace` or image change on `digitalocean_droplet.this["fantasy-hockey"]`               | droplet `-/+`, assignment `-/+`, **no** change to any `digitalocean_record`                                                                                    | N/A: the record references the reserved IP, which `prevent_destroy` keeps                                                                                 |
| Reserved IP changes          | the reserved IP is replaced by deliberately lifting `prevent_destroy`, or a region change | `digitalocean_record.a["fantasy-hockey.prod"]` `~ value`, in place                                                                                             | outage for the remaining TTL of cached answers (300 s), see `dns-zone.md`                                                                                 |
| App moves to another droplet | the app's map key or tag moves to another droplet entry                                   | old name `-`, new name `+`, or `~ value` when the name stays and the reserved IP changes                                                                       | the deploy guard stops the deploy until the new record resolves                                                                                           |
| App added                    | new droplet entry with `reserved_ip = true`                                               | droplet, reserved IP, assignment and A `<key>.<stage>` created in one apply                                                                                    | first deploy waits until the name resolves; negative caching of an earlier NXDOMAIN lasts up to the zone's SOA minimum (read it in M4)                    |
| App removed                  | droplet entry removed                                                                     | record `-`. The reserved IP and volume refuse to be destroyed (`prevent_destroy`), so the plan fails until they are handled deliberately                       | the record goes in the same apply as the droplet. Never leave a record on a released reserved IP (Story 7.1 "Remove the Record")                          |
| Two names, one droplet       | `dns_aliases = ["hockey.prod"]` on the `fantasy-hockey` entry                             | second A record with the same reserved IP reference                                                                                                            | alias not ending in `.prod` → precondition error                                                                                                          |
| External target              | `dns_external_records = { "status.prod" = "203.0.113.10" }`                               | A `status.prod` with the literal value                                                                                                                         | not an IPv4 address → precondition error; name collides with a derived name → precondition error                                                          |
| Same app in several stages   | `fantasy-hockey` in `prod` and a second key for `test`                                    | `fantasy-hockey.prod` and `fantasy-hockey.test`                                                                                                                | the map key is unique per droplet, so the second stage needs its own key. Document how a key that is not the app name maps to `<app>`; see Open Questions |
| Droplet without reserved IP  | `reserved_ip = false`                                                                     | no record                                                                                                                                                      | documented: such a droplet has no public name                                                                                                             |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/opentofu/droplets.tf`: the `droplets` map (options documented in its header comment), `droplets_with_reserved_ip`, and `digitalocean_droplet.this` named `"${stage}-${key}"`. Add the optional option `dns_aliases` (list of names relative to the zone, default `[]`) to the header comment, the same way as `tags`.
- `configs-cloud/digital-ocean/opentofu/reserved-ips.tf`: `digitalocean_reserved_ip.this` (`prevent_destroy`) and `digitalocean_reserved_ip_assignment.this`. The record value is `digitalocean_reserved_ip.this[key].ip_address`, the same attribute the assignment uses.
- `configs-cloud/digital-ocean/opentofu/project.tf`: `digitalocean_project_resources.this` concatenates droplet, volume and reserved IP URNs. Add `digitalocean_domain.this.urn` so the zone appears in project `sommerfeld.io` like every other resource (`docs/cloud/digital-ocean/index.md` "All resources belong to the project").
- `configs-cloud/digital-ocean/opentofu/outputs.tf`: add `dns_records` (FQDN → IPv4 for every A record) and `dns_zone` (zone name). Keyed like the existing outputs.
- `configs-cloud/digital-ocean/opentofu/versions.tf`: provider `digitalocean/digitalocean` `2.106.0`. Resources used are `digitalocean_domain` (import by name) and `digitalocean_record` (import `<domain>,<record-id>`; `ttl` default 1800, minimum 30 at DigitalOcean; CAA uses `flags` and `tag`).
- `configs-cloud/digital-ocean/opentofu/taskfile.yml`: `init`, `fmt`, `plan`, `apply`, `apply:yes`. Add `validate` (`tofu validate`). Document `tofu plan -detailed-exitcode` (exit 0 = no changes) in `dns-zone.md` as the "no unnecessary change" check.
- `configs-cloud/taskfile.yml`: add `dns:check`, which runs `dig` in a pinned container. The devcontainer has no `dig`, `nslookup`, `host` or `drill` (checked 2026-10-15), and DNS over HTTPS cannot query a specific authoritative server. Add a service with a pinned image tag to `docker-compose.yml`, like the linters. Arguments after `--` pass through, e.g. `task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A`.
- `docker-compose.yml`: `lint-opentofu` (`ghcr.io/opentofu/opentofu:1.12.7`, `fmt -check`) covers the new file automatically. Add the `dig` service here.
- `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/tasks/dns.yml`: the guard compares `getent ahostsv4` with the reserved IP. It stays unchanged in this story (KAS is still authoritative). Story 8.2 updates its `fail_msg`.
- `docs/cloud/digital-ocean/`:
    - `droplet.md` §Files, which lists the `.tf` files;
    - `api-token.md` §Token Scopes, which says "`domain` is not needed";
    - `index.md`, with the "What Runs Where" `kroki-plantuml` diagram, Resources and Pages;
    - `tasks-and-linters.md` §Tasks.
- `mkdocs.yml` nav `Cloud → Digital Ocean`: add `DNS Zone: cloud/digital-ocean/dns-zone.md` after `Domain`.
- Diagrams are `kroki-plantuml` fenced blocks inside the Markdown page (`mkdocs.yml` plugin `kroki`; examples in `docs/cloud/index.md` and `docs/cloud/digital-ocean/index.md`). The repo keeps no separate `.puml` files, so the source lives in the page.

## Tasks & Acceptance

**Execution:**

- [ ] **Pre-check (agent, read-only):** run `doctl compute domain list` and record whether `do.sommerfeld.app` or `sommerfeld.app` already exists in the account. If either exists, stop and add an import step (Design Notes). Needs `domain:read`, so this runs after M1.
- [ ] `opentofu/dns.tf`:
    - `locals`: `dns_zone = "do.sommerfeld.app"`, `dns_ttl = 300`, `dns_droplet_records` (from `droplets_with_reserved_ip`), `dns_alias_records`, `dns_external_records` (empty map with a commented example), `dns_a_records` (merge of the three);
    - `digitalocean_domain.this` with `prevent_destroy` and the duplicate, alias and external preconditions;
    - `digitalocean_record.a` with `for_each = local.dns_a_records`;
    - `digitalocean_record.caa` at `@`.

  Each block gets a "why" comment. Result: the zone and the records are declared, with no copied IP.
- [ ] `droplets.tf` header comment: document `dns_aliases`, and read it with `try(each.value.dns_aliases, [])` like `tags`. Result: case 5 (several names, one droplet) is supported without a new resource type.
- [ ] `project.tf`: add the domain URN. `outputs.tf`: add `dns_records` and `dns_zone`. Result: `tofu output dns_records` replaces the manual lookup.
- [ ] `opentofu/taskfile.yml` (`validate`), `configs-cloud/taskfile.yml` (`dns:check`), `docker-compose.yml` (pinned `dig` image). Result: authoritative queries work from the devcontainer.
- [ ] Offline proof: `tofu fmt -check`, `tofu validate`, `task lint`. Then run `tofu plan -out=dns.tfplan` (needs the token with `domain:read`, so after M1) and `tofu show -json dns.tfplan | jq` to list every resource action. Record the action list in Implementation Notes. The only allowed actions are `create` on DNS resources and `update` on `digitalocean_project_resources.this`. Any `delete` or replacement aborts. Delete the plan file afterwards (it may contain state data). Result: the plan is reviewed before the operator applies.
- [ ] New page `docs/cloud/digital-ocean/dns-zone.md`:
    - Architecture: the two zones, which provider is authoritative for which zone, and that the DigitalOcean zone serves nothing publicly until Story 8.2 delegates it. Diagram A.
    - Records: the derivation rule, `dns_aliases`, `dns_external_records`, TTLs and CAA.
    - How-tos:
        - add an app hostname;
        - update a target IP;
        - remove a hostname safely: the record goes with the droplet, never left on a released IP;
        - a recreated droplet: no DNS change;
        - move an app to another droplet;
        - an external IP;
        - the same app in another stage.
    - Plan and review: `init`, `validate`, `plan -out`, read the actions, `apply` the saved plan, and a second plan shows `No changes.`.
    - Import of an existing zone or record.
    - Checks with `task cloud:dns:check` against `ns1.digitalocean.com`, plus troubleshooting:
        - NXDOMAIN;
        - the old all-inkl answer;
        - a perpetual diff;
        - a token without `domain` scope (403).
    - Recovery from a wrong record: fix and apply. A zone deleted outside OpenTofu: `apply` recreates it, and the NS hostnames are the same for every DigitalOcean zone, so the delegation needs no change.
    - Automated vs manual table.
    - Diagram B.
- [ ] Diagram A (`kroki-plantuml` component or deployment diagram) in `dns-zone.md`:
    - the `.app` registry;
    - registrar and parent zone at all-inkl.com (`ns5`/`ns6.kasserver.com`), labelled authoritative for `sommerfeld.app`;
    - the NS delegation `do` → `ns1-3.digitalocean.com`, labelled "Story 8.2, manual in the KAS";
    - the DigitalOcean zone `do.sommerfeld.app`, labelled authoritative for `do.sommerfeld.app` and below;
    - OpenTofu → DigitalOcean API → zone and records;
    - A `fantasy-hockey.prod` → reserved IP → droplet `prod-fantasy-hockey` (Caddy :443);
    - the client resolution path through a recursive resolver.

  Mark manual elements with a `<<manual>>` stereotype or a note.
- [ ] Diagram B (`kroki-plantuml` sequence diagram) in `dns-zone.md`. Actors: Operator, OpenTofu, DigitalOcean API, reserved IP, droplet, DigitalOcean DNS, recursive resolver, client. Two groups:
    - **Droplet replaced:** the record is unchanged, the reserved IP is re-assigned, and clients keep the same answer.
    - **Reserved IP or target changed:** `plan` shows `~ value`, the operator reviews and applies, the API updates the record, and resolvers serve the old value until the TTL expires before they ask again.

  Separate the infrastructure change, the DNS update and the caching phase with `== ... ==` dividers.
- [ ] Update the pages from the Code Map:
    - `droplet.md` §Files: add `dns.tf`;
    - `api-token.md`: the `domain` scope row (create, read, update, delete) and why. Remove "`domain` is not needed";
    - `index.md`: the "What Runs Where" diagram gets the DNS zone (declared, not yet delegated), plus Resources and Pages rows;
    - `tasks-and-linters.md`: `validate`, `dns:check`;
    - `mkdocs.yml` nav.

  `domain.md` stays as it is except for one sentence linking `dns-zone.md` and saying the KAS record remains authoritative until Story 8.2. Result: the docs describe what is live.
- [ ] Planning docs:
    - `_bmad-output/specs/spec-fantasy-hockey-digitalocean/SPEC.md` §Constraints, the DNS bullet;
    - the `ARCHITECTURE-SPINE.md` AD-10 **DNS** bullet.

  Both are reworded to: "`do.sommerfeld.app` is delegated from all-inkl.com to DigitalOcean DNS and declared in OpenTofu; `sommerfeld.app` and its other records stay at all-inkl.com; the token has the `domain` scope". Add "(from Story 8.2 on)" to the delegation clause. Result: the canonical contracts no longer forbid what this epic builds (retro item 27).
- [ ] Validate diagrams: render each block through the docs build (`task docs:run`, or the `docs-build` service). Also run `docker run --rm plantuml/plantuml:<pinned tag> -syntax` on the extracted source, unprivileged and without a host mount (pipe the source through stdin). Record the result. Result: no diagram ships broken.

**Acceptance Criteria:**

- Given the change, when `task lint`, `tofu -chdir=configs-cloud/digital-ocean/opentofu validate` and `tofu fmt -check -recursive configs-cloud` run, then they pass.
- Given the token has the `domain` scopes, when `tofu plan` runs before any apply, then its only actions are creating `digitalocean_domain.this`, `digitalocean_record.a["fantasy-hockey.prod"]` and `digitalocean_record.caa`, plus an in-place update of `digitalocean_project_resources.this`. No droplet, volume, reserved IP or assignment changes, and nothing is destroyed or replaced.
- Given the A record's value expression, when it is read, then it references `digitalocean_reserved_ip.this[...]` and contains no literal IP. The only literal IPs in `dns.tf` are entries of `dns_external_records`.
- Given the operator applied (M4), when `tofu plan -detailed-exitcode` runs again, then it exits 0 (`No changes.`).
- Given the applied zone, when `task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A` runs, then the answer is authoritative (`aa` flag) with the reserved IP from `tofu output reserved_ip_addresses`. `@ns2` and `@ns3` agree. `CAA` at `do.sommerfeld.app` returns `0 issue "letsencrypt.org"`. An undeclared name returns NXDOMAIN.
- Given the change, when public resolvers are asked for `fantasy-hockey.prod.do.sommerfeld.app` and `NS do.sommerfeld.app`, then the answers are the same as before the change: the KAS A record, and the wildcard CNAME for `do`. Nothing public changed.
- Given a temporary local edit that sets a different value in `dns_external_records` or adds a duplicate alias, when `tofu plan` runs, then the plan shows `~ value` in place for the external record, and the duplicate fails with the precondition message. The edit is not committed, and the output goes into Implementation Notes.
- Given `dns-zone.md`, when the site is built, then the page is in the nav after Domain, and diagrams A and B render. Each how-to from Tasks is present, and every manual step is marked as manual.

## Manual Tasks (Operator)

Every step below needs the operator. The agent marks none of them as done, and records their results in Implementation Notes only after the operator reports them.

| #  | When             | Where                                                        | Action                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Why                                                                                       | Verify                                                                                                                                                                   | Risk / rollback                                                                                                                     |
|----|------------------|--------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| M1 | before the plan  | DigitalOcean control panel → API → Tokens                    | Add the `domain` scope with `create`, `read`, `update` and `delete` to the custom-scoped token behind `DIGITALOCEAN_ACCESS_TOKEN`. Whether the panel lets an existing token's scopes be edited is unverified. If it does not, generate a new token with the scopes from `api-token.md` plus `domain`. Then: <br>• put the new token into `configs-homelab/ansible/vars/vault.yml` (key `DIGITALOCEAN_TOKEN`, `task homelab:ansible:vault`); <br>• re-run the `desktop` playbook; <br>• rebuild the devcontainer; <br>• revoke the old token. | OpenTofu cannot read or create zones without the scope                                    | `doctl compute domain list` succeeds (an empty list is fine). Before M1 it fails with 403                                                                                | none for DNS. A new token that misses a scope breaks every cloud task until fixed. Keep the old token until the new one is verified |
| M2 | before the plan  | devcontainer                                                 | `doctl compute domain list` (or let the agent run it). Note whether `sommerfeld.app` or `do.sommerfeld.app` exists in the account                                                                                                                                                                                                                                                                                                                                                                                                            | an existing zone must be imported, not created twice                                      | output recorded in Implementation Notes                                                                                                                                  | read-only                                                                                                                           |
| M3 | before the apply | devcontainer, `configs-cloud/digital-ocean/opentofu`         | Back up the state: `cp terraform.tfstate ~/tfstate-backups/terraform.tfstate.pre-dns-$(date +%Y%m%d%H%M)` (outside the repo)                                                                                                                                                                                                                                                                                                                                                                                                                 | state is local and gitignored. A broken apply must be recoverable                         | the backup file exists and is non-empty                                                                                                                                  | read-only                                                                                                                           |
| M4 | after the merge  | devcontainer                                                 | Run `task cloud:digital-ocean:opentofu:plan`, read the actions (as in the second AC), then `task cloud:digital-ocean:opentofu:apply` and answer `yes` only when the plan matches. Then read the zone's NS and SOA: `doctl compute domain records list do.sommerfeld.app --format Type,Name,Data,TTL`                                                                                                                                                                                                                                         | creates the zone and records at DigitalOcean. Still nothing public                        | `tofu output dns_records`; a second `plan` says `No changes.`; the authoritative check in the ACs passes. Record the NS hostnames and SOA values in Implementation Notes | no outage: the zone is not delegated. Rollback: leave the zone (harmless), or lift `prevent_destroy` deliberately and destroy it    |
| M5 | after M4         | devcontainer                                                 | `task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A`, the same for `ns2`/`ns3`, `CAA do.sommerfeld.app`, and an undeclared name                                                                                                                                                                                                                                                                                                                                                                    | proves DigitalOcean serves a subdomain zone authoritatively before Story 8.2 relies on it | `aa` flag, reserved IP, CAA, NXDOMAIN as expected                                                                                                                        | read-only. If DigitalOcean does not answer authoritatively, stop the epic and use the fallback in Design Notes                      |
| M6 | after M5         | outside the home network (phone hotspot or public resolvers) | Check public resolution is unchanged (DoH commands from `domain.md` §Check)                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | confirms this story had no public effect                                                  | Google and Cloudflare still return `129.212.195.118` for the app name                                                                                                    | read-only                                                                                                                           |

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

**Inspection on 2026-10-15 (`947925c`).**

| Item                       | State                                                                                                                                                                                                                           |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| OpenTofu root              | one root, `configs-cloud/digital-ocean/opentofu/`: `droplets.tf`, `reserved-ips.tf`, `volumes.tf`, `project.tf`, `outputs.tf`, `versions.tf`. No modules, no variables, no workspaces, configuration in `locals`                |
| State                      | local `terraform.tfstate`, gitignored (`.gitignore` `*.tfstate`). Remote state with locking is Story 6.2                                                                                                                        |
| Provider auth              | `provider "digitalocean" {}` reads `DIGITALOCEAN_ACCESS_TOKEN`. The token comes from the vault through `bash-secrets.yml` and the devcontainer `containerEnv` (`api-token.md`). No `domain` scope today                         |
| IP exposure                | outputs `droplet_ipv4_addresses`, `reserved_ip_addresses` (`{"prod-fantasy-hockey":"129.212.195.118"}`), `volume_mount_paths`                                                                                                   |
| Environments               | the stage is a per-droplet field (`dev`/`test`/`prod`, not validated: retro item 25). It builds the droplet name `<stage>-<key>`, the tag and the Alloy label                                                                   |
| DNS in the repo            | no `digitalocean_domain` or `digitalocean_record`. The hostname is derived in Ansible (`deploy-fantasy-hockey.yml` `fantasy_hockey_domain`), and `tasks/dns.yml` stops the deploy unless it resolves to exactly the reserved IP |
| DNS consumers              | the deploy guard and the Caddy certificate (HTTP-01/TLS-ALPN, needs the name to resolve to the droplet). Story 5.2 (backlog) will probe the HTTPS URL. Nothing reads the KAS directly                                           |
| Linters                    | `lint-opentofu` (`fmt -check` only), no `tofu validate` anywhere, no tflint. CI static checks for OpenTofu are Story 6.1                                                                                                        |
| Diagrams                   | inline `kroki-plantuml` blocks rendered by the mkdocs `kroki` plugin. No local PlantUML tool                                                                                                                                    |
| Live DNS (DoH, 2026-10-15) | Results below                                                                                                                                                                                                                   |

Live DNS results (DoH):

- `sommerfeld.app` has the NS records `ns5`/`ns6.kasserver.com` (TTL 7200) and SOA `ns5.kasserver.com. hostmaster.kasserver.com. … 7200` (negative TTL 7200).
- It has **no DS record** at `.app`, so it is not DNSSEC-signed.
- `fantasy-hockey.prod.do` is an A record with the value `129.212.195.118` (TTL 7200).
- `do` and `prod.do` resolve through the wildcard CNAME to `w00f8074.kasserver.com` → `85.13.131.235`.
- There is no CAA record anywhere up to the apex.
- There is no `_acme-challenge` TXT record.

Sources checked on 2026-10-15:

- DigitalOcean nameservers are `ns1`, `ns2` and `ns3.digitalocean.com` ([DNS registrars](https://docs.digitalocean.com/products/networking/dns/getting-started/dns-registrars/)).
- DigitalOcean DNS "does not support creating DNSSEC (DS) records", a minimum TTL of 30 s applies, and CAA values must not be a bare `;` and must not carry name-value tags ([limits](https://docs.digitalocean.com/products/networking/dns/details/limits/)).
- "DNS management is free" ([pricing](https://docs.digitalocean.com/products/networking/dns/details/pricing/)).
- The token scopes are `domain:create`, `domain:read`, `domain:update` and `domain:delete` ([scopes](https://docs.digitalocean.com/reference/api/scopes/)).
- `digitalocean_domain` is imported by its name. `ip_address` creates an initial A record. `digitalocean_record` is imported as `<domain>,<id>` ([domain](https://github.com/digitalocean/terraform-provider-digitalocean/blob/main/docs/resources/domain.md), [record](https://github.com/digitalocean/terraform-provider-digitalocean/blob/main/docs/resources/record.md)).

**Feasibility gap:** DigitalOcean documents its DNS around apex domains. No official page walks through hosting a delegated subdomain zone. Community reports say it works ([question](https://www.digitalocean.com/community/questions/subdomain-dns-delegation-in-digital-ocean), [Let's Encrypt forum](https://community.letsencrypt.org/t/delegating-deployment-of-dns-01-challenge-records-to-a-subdomain-using-digitalocean-and-caddy/223766)). M4 and M5 prove it without public effect: when the API accepts `do.sommerfeld.app` and `ns1.digitalocean.com` answers it with `aa`, delegation in Story 8.2 is plain RFC 1034 NS delegation. The API may also refuse the name, for example because another account holds `sommerfeld.app`. In that case, stop and pick one of these fallbacks:

1. **Recommended fallback:** keep the manual KAS record as the documented exception (status quo, Story 7.1), and re-plan.
2. Delegate `do.sommerfeld.app` to another DNS provider with an OpenTofu provider. This adds a vendor and a secret.
3. Move all of `sommerfeld.app` to DigitalOcean nameservers. This migrates unrelated records and is rejected unless nothing else works.
4. Manage the KAS zone through the KAS API. No maintained OpenTofu provider for the KAS was verified, so this is unknown.

**Import:** the KAS records are not importable: they belong to another provider, so they are recreated at DigitalOcean, not imported. If `do.sommerfeld.app` already exists at DigitalOcean (M2), import it before the first apply:

- `tofu import 'digitalocean_domain.this' do.sommerfeld.app`
- `tofu import 'digitalocean_record.a["fantasy-hockey.prod"]' do.sommerfeld.app,<id>`, with `<id>` from `doctl compute domain records list do.sommerfeld.app`

Then confirm that `plan` shows no create for them. DigitalOcean's own SOA and NS records at the apex are created by DigitalOcean and stay unmanaged; never declare them.

**Why the reserved IP and no new infrastructure:** the reserved IP already exists, survives replacement and is the address Caddy's certificate and the deploy guard already rely on. A record on the droplet's own IPv4 would change on every replacement and break the guard. Nothing new is bought: DigitalOcean DNS is free, and the $6.20/month budget is unchanged.

**Dependencies between resources:** the record references `digitalocean_reserved_ip.this[key]`, so OpenTofu orders it after the reserved IP. The record does not reference the droplet, so a droplet replacement never touches it. The project resources reference the domain URN.

**Open questions:**

- Can an existing DigitalOcean token's scopes be edited, or must it be regenerated (M1)?
- `<app>` in the hostname is the map key. Two stages of the same app need two keys (`fantasy-hockey` and, for example, `fantasy-hockey-test`), but the hostname must stay `fantasy-hockey.test`. Should the entry get an optional `app` field (default: the key), and must the Ansible derivation in `deploy-fantasy-hockey.yml` (`inventory_hostname.split('-', 1)`) follow it? This decision is needed before a second stage exists. Until then, only `prod` exists, and the default covers it.
- Should `dns_aliases` stay DNS-only, or should a later story let Caddy serve aliases?
- TTL 300 for A records: confirm, or use the DigitalOcean default of 1800.
- The stage list validation (retro item 25) would also protect the hostnames. Should it be folded in here, or stay with the dev loop?

## Verification

**Commands:**

- `task lint`: all linters pass, including `lint-opentofu`.
- `tofu -chdir=configs-cloud/digital-ocean/opentofu validate`: `Success!`.
- `tofu -chdir=configs-cloud/digital-ocean/opentofu plan -out=dns.tfplan && tofu -chdir=configs-cloud/digital-ocean/opentofu show -json dns.tfplan | jq -r '.resource_changes[] | select(.change.actions != ["no-op"]) | "\(.change.actions|join(",")) \(.address)"'`: only `create` lines for DNS resources and one `update` for `digitalocean_project_resources.this`. Needs the token with `domain:read`.
- After M4: `tofu plan -detailed-exitcode` exits 0.
- `task cloud:dns:check -- +norec @ns1.digitalocean.com fantasy-hockey.prod.do.sommerfeld.app A`: `aa`, reserved IP.

**Not verifiable by the agent:** the apply, the token change and public resolution from outside the home network. These are M1 to M6.
