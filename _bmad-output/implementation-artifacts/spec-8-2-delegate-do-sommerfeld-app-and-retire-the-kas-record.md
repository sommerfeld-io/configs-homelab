---
title: 'Story 8.2: Delegate do.sommerfeld.app and retire the KAS record'
type: 'refactor'
created: '2026-10-15'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/spec-8-1-digitalocean-dns-zone-do-sommerfeld-app-in-opentofu.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-7-1-dns-record-for-the-droplet.md'
    - '{project-root}/_bmad-output/implementation-artifacts/epic-7-retro-2026-10-15.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After Story 8.1, DigitalOcean serves a correct zone `do.sommerfeld.app`, but no resolver asks it. The parent zone `sommerfeld.app` at all-inkl.com still answers `fantasy-hockey.prod.do.sommerfeld.app` from the hand-made A record. It answers `do` and `prod.do` with the wildcard CNAME to `w00f8074.kasserver.com`. DNS authority moves only when the parent zone delegates `do`, and that change can only be made by hand in the KAS. OpenTofu cannot do it.

**Approach:** The agent writes the migration and rollback runbook (`docs/cloud/digital-ocean/dns-delegation.md`, with diagram C). It reconciles every doc, the deploy guard message and the planning docs with the delegated architecture. The operator follows the runbook. The runbook adds three NS records `do` → `ns1`/`ns2`/`ns3.digitalocean.com.` in the KAS while the old A record stays. Both providers answer the same IP, so no resolver sees a wrong address during the switch. The operator verifies the delegation through authoritative and public queries, plus HTTPS. Only after a wait of at least twice the parent TTL (2 × 7200 s) is the obsolete KAS A record deleted. Every step has a recorded rollback.

**Decisions (proposed 2026-10-15, confirm before build):**

- **Add the NS records first, delete the A record last.** This avoids any window in which the name falls back to the wildcard (`85.13.131.235`), which would break HTTPS and the Caddy renewals.
- **The KAS TTL is not lowered.** The KAS sets 7200 s (Story 7.1 notes). With identical answers on both sides, caching does not cause an outage, only a slow switch.
- **The CAA records from retro item 26 go into the DigitalOcean zone (Story 8.1), not into the KAS.** Once delegated, CAA lookups for every name under `do` stop at `do.sommerfeld.app`, so the wildcard CNAME no longer answers them.

## Boundaries & Constraints

**Always:**

- The runbook names, for every step:
    - who does it: agent, operator, or OpenTofu;
    - where: KAS, devcontainer, or outside the home network;
    - whether it is safe to repeat;
    - its outage risk;
    - its rollback.
- Verify against authoritative servers (`task cloud:dns:check -- +norec @ns5.kasserver.com …` and `@ns1.digitalocean.com …`) **and** independent public resolvers (Google and Cloudflare DoH, as in `domain.md` §Check). One resolver is never enough.
- Keep the DigitalOcean zone (`prevent_destroy`) through any rollback until all caches of the delegation have expired, so a resolver that still holds the DigitalOcean NS records keeps getting correct answers.
- Record each operator result (with the `date` timestamp) in Implementation Notes. Mark no manual step as done that the operator has not reported.
- Docs, diagrams and planning docs change in the same commit. `task lint` passes.

**Never:**

- No change to the registrar, the nameservers of `sommerfeld.app`, its wildcard, or any record outside `do` and below it.
- The agent never logs in to the KAS, never runs `tofu apply` and never runs the deploy (vault password).
- Do not delete the KAS A record before step M13's wait has passed and M12 has passed.
- Do not delete the DigitalOcean zone as part of a rollback.
- No `tofu destroy`, no `-target` destroy, no `force`.

## I/O & Edge-Case Matrix

| Scenario                                           | State                                          | Expected                                                                                                                                           | Handling                                                                                                                                                                                                             |
|----------------------------------------------------|------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Before NS records                                  | 8.1 applied                                    | `@ns5.kasserver.com NS do.sommerfeld.app` returns the wildcard CNAME, and public resolvers return the KAS A record                                 | baseline, recorded in M8                                                                                                                                                                                             |
| NS records added                                   | KAS has NS `do` ×3 and the old A record        | `@ns5.kasserver.com` returns a referral (authority section NS ×3, no `aa`) for names under `do`; public answers are `129.212.195.118` either way   | if the KAS still answers the A record with `aa` (occluded data served), the delegation is ineffective for that name: open a support ticket with all-inkl (see Open Questions); the old A record keeps the service up |
| KAS refuses the NS records                         | KAS error while the A record exists below `do` | no change                                                                                                                                          | stop. Do not delete the A record to make room: that opens a window in which the name may resolve to the wildcard. Re-plan with the operator                                                                          |
| Resolver cached the wildcard for `do`              | earlier `NS do.sommerfeld.app` lookup          | the old CNAME answer for up to 7200 s                                                                                                              | wait. The app name keeps working through the A record                                                                                                                                                                |
| A record deleted at KAS                            | M14 done                                       | the KAS still refers; the A record answers only from DigitalOcean                                                                                  | if anything fails, recreate the A record in the KAS (rollback R3)                                                                                                                                                    |
| Wrong IP in the DigitalOcean zone after delegation | plan or apply mistake                          | HTTPS fails for up to 300 s after the fix                                                                                                          | fix in OpenTofu and apply. Caddy renewals retry                                                                                                                                                                      |
| DNSSEC enabled later on `sommerfeld.app`           | DS appears at `.app`                           | the delegation to an unsigned DigitalOcean zone stays valid as an insecure delegation, if the KAS signs the NS records with an NSEC proof of no DS | a DS record for `do` must never be added: DigitalOcean cannot sign. Recheck in the runbook                                                                                                                           |

</frozen-after-approval>

## Code Map

- `docs/cloud/digital-ocean/domain.md`: the Story 7.1 page. Rewrite it for the delegated state:
    - Record: in the DigitalOcean zone, from `tofu output dns_records`;
    - "Why DNS Is Not in OpenTofu" becomes "Where DNS Lives", with a link to `dns-zone.md`;
    - "Create the Record" and "Remove the Record" point to the how-tos in `dns-zone.md`;
    - the wildcard paragraph now applies only outside `do`;
    - the CAA paragraph is now served by the DigitalOcean zone;
    - Check covers both authoritative servers and public resolvers.

  This also fixes the open Epic 7 retro findings 3, 5 and 10 that touch this page: the wildcard is a CNAME, the new-droplet order, the TTL. Coordinate with retro item 24 if it lands first.
- `docs/cloud/digital-ocean/dns-zone.md`: from Story 8.1. Remove "not yet delegated" and link the delegation page.
- `docs/cloud/digital-ocean/index.md`:
    - the "What Runs Where" diagram: the delegation edge becomes solid and "manual, KAS";
    - the **Domain** bullet: "kept by hand at all-inkl.com, outside OpenTofu" becomes "declared in OpenTofu in the delegated zone";
    - the Pages table.
- `docs/cloud/index.md`: the activity diagram step 1 note ("Droplet, reserved IP and volume") adds the DNS records. The end node "App reachable at the reserved IP" is stale since Story 7.2: change it to the domain.
- `docs/cloud/digital-ocean/replacement.md` and `deployment.md` §DNS Check: the record lives in OpenTofu, and a replacement still changes nothing. `deployment.md` mentions "among the addresses" (retro finding 1).
- `docs/cloud/domain-naming.md` last line: link `dns-zone.md` as well.
- `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/tasks/dns.yml` `fail_msg`: replace "Create or fix the A record as described in docs/cloud/digital-ocean/domain.md and check it with `dig +short …`" with: check `tofu output dns_records` and apply OpenTofu (`docs/cloud/digital-ocean/dns-zone.md`); on the droplet, check with `getent ahostsv4 <domain>`. This fixes retro finding 2 at the same time. `README.md` of the role (copied into `docs/cloud/ansible/roles/fantasy-hockey.md` by `task docs:generate`; edit the README) and `deploy-fantasy-hockey.yml` comment ("The A record is created by hand"): same reconciliation.
- `configs-cloud/digital-ocean/tests/molecule/fantasy-hockey/molecule/default/`: check whether verify asserts on the `fail_msg` text. If so, update it. The scenario stays unprivileged.
- `mkdocs.yml` nav: `DNS Delegation: cloud/digital-ocean/dns-delegation.md` after `DNS Zone`.
- Planning docs:
    - `SPEC.md` and `ARCHITECTURE-SPINE.md` AD-10: drop "(from Story 8.2 on)";
    - `_bmad-output/specs/spec-fantasy-hockey-digitalocean/epics.md` E6 bullet ("created by hand at all-inkl.com"): reword it;
    - `_bmad-output/implementation-artifacts/epic-7-context.md` "DNS is outside the declaration": add a superseded note pointing to Epic 8.

## Tasks & Acceptance

**Execution (agent):**

- [ ] New page `docs/cloud/digital-ocean/dns-delegation.md`:
    - Responsibilities table:
        - all-inkl.com: registrar, parent zone, the three NS records, everything outside `do`;
        - DigitalOcean: zone `do.sommerfeld.app`, every record under it;
        - OpenTofu: the zone and records;
        - the operator: the KAS steps, the token, the apply.
    - "Delegation" section: the exact KAS records.
    - Migration runbook M7 to M16, copied from Manual Tasks below and adapted to what Story 8.1 recorded (NS hostnames, SOA values).
    - Rollback R1 to R4.
    - Troubleshooting: lame delegation, a cached wildcard, a referral without glue (not needed: the DigitalOcean nameservers are outside the zone), DNSSEC, CAA.
    - Diagram C.

  Result: the operator has one page to follow, and it stays as the recovery reference.
- [ ] Diagram C (`kroki-plantuml` sequence diagram) in `dns-delegation.md`. Participants: Operator (stereotype `<<manual>>`), KAS (all-inkl.com), parent zone `sommerfeld.app`, OpenTofu, DigitalOcean API, DigitalOcean DNS, public resolvers, droplet (Caddy). Groups in order:
    - Inventory and preparation;
    - Zone created and validated (Story 8.1, reference only);
    - NS delegation at the KAS;
    - Import: none expected, `alt` when M2 found a zone;
    - DNS verification;
    - HTTPS verification;
    - Wait 2 × TTL;
    - Remove the obsolete A record;
    - Final checks.

  Add an `alt` "validation fails" branch for each verification group, leading to the matching rollback R1 to R4. Every KAS action is a message from Operator to KAS labelled "manual".
- [ ] Reconcile every file in the Code Map. Result: nothing says the record is kept by hand or that the token needs no `domain` scope. Check with `git grep -n -i -E "by hand at all-inkl|domain. is not needed|outside OpenTofu|dig \+short"` over `docs/` and `configs-cloud/`.
- [ ] Validate the diagrams as in Story 8.1 (docs build, plus `plantuml -syntax` in a pinned, unprivileged container fed through stdin).
- [ ] Dry-run the runbook as a read-only walk: run each verification command once **before** M10 and record the baseline output. A command that cannot run (tool missing, flag wrong) is fixed in the runbook before the operator starts.
- [ ] After the operator reports M7 to M16: record the results in Implementation Notes. Update `domain.md` with the date the delegation went live and the date the KAS record was removed.

**Acceptance Criteria:**

- Given the KAS NS records, when `task cloud:dns:check -- +norec @ns5.kasserver.com fantasy-hockey.prod.do.sommerfeld.app A` runs, then the answer is a referral to `ns1`/`ns2`/`ns3.digitalocean.com` (no `aa`, NS in the authority section). The same holds for `@ns6.kasserver.com`.
- Given the delegation, when `dns.google` and `cloudflare-dns.com` are asked for `NS do.sommerfeld.app`, `A fantasy-hockey.prod.do.sommerfeld.app` and `CAA do.sommerfeld.app`, then they return the DigitalOcean nameservers, the reserved IP from `tofu output reserved_ip_addresses` and `0 issue "letsencrypt.org"`. `task cloud:dns:check -- +trace fantasy-hockey.prod.do.sommerfeld.app` ends at a DigitalOcean nameserver.
- Given the delegation, when a name outside `do` is queried (`sommerfeld.app`, `www.sommerfeld.app`, any other record listed in M7), then the answer equals its M7 baseline: unrelated records are unaffected.
- Given the migrated DNS, when `https://fantasy-hockey.prod.do.sommerfeld.app/` is opened from outside the home network, then it behaves as in the Epic 7 retro: `302` to `/login`, `/login` `200`, `http://` redirects with `308`, `/metrics` returns `404`, and the certificate issuer and expiry are unchanged.
- Given M14, when the KAS zone is listed, then it has no A record `fantasy-hockey.prod.do` and exactly the three NS records for `do`. Public resolution is still correct after 2 × 7200 s.
- Given the change, when a deploy runs (`task cloud:digital-ocean:ansible:deploy-fantasy-hockey`, operator), then the DNS guard passes. A deliberately undeclared name would print the new `fail_msg`, checked with Molecule or by reading the template, not live.
- Given the docs, when the site is built, then `dns-delegation.md` is in the nav and diagram C renders. Every manual step is labelled manual, and the rollback procedures R1 to R4 exist. The grep from Tasks finds no stale statement.
- Given the planning docs, when they are read, then SPEC, spine AD-10, spec `epics.md` and `epic-7-context.md` describe the delegated, OpenTofu-managed zone.

## Manual Tasks (Operator)

Continues the numbering of Story 8.1, where M1 to M6 are the token, zone check, state backup, apply, authoritative check and public check. Do them in order. None of them is done yet.

| #   | When                                     | Where                                                                    | Exact action                                                                                                                                                                                                                                                                                                                                                                                                                                   | Why                                                                                                                  | Verify                                                                                                                                                                                 | Repeat-safe / outage / rollback                                                                                    |
|-----|------------------------------------------|--------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| M7  | before (after the agent's runbook merge) | KAS → Tools → DNS-Einstellungen → `sommerfeld.app` (edit)                | Inventory: screenshot or copy every record of the zone, especially every name that is `do` or ends in `.do`, the wildcard `*`, any NS, CAA or TXT record, and the TTLs. Also open Domain → Subdomains and note whether a KAS subdomain `do.sommerfeld.app` or `*.do.sommerfeld.app` exists                                                                                                                                                     | baseline for "unrelated records unaffected" and for rollback. A KAS subdomain for `do` would collide with NS records | the list is in Implementation Notes. As of 2026-10-15 (public DoH) the only record under `do` was A `fantasy-hockey.prod.do` `129.212.195.118` TTL 7200; the zone has no DS and no CAA | read-only                                                                                                          |
| M8  | before                                   | devcontainer                                                             | Baseline: run the runbook's verification commands (authoritative `@ns5`/`@ns6.kasserver.com` and `@ns1.digitalocean.com`, plus public DoH) and keep the output                                                                                                                                                                                                                                                                                 | proves the starting state and that Story 8.1's zone is correct before authority moves                                | DigitalOcean answers `aa` with the reserved IP and the CAA record; KAS answers the old A record                                                                                        | read-only. If DigitalOcean is wrong, fix it in OpenTofu first                                                      |
| M9  | before                                   | KAS → Tools → DNS-Einstellungen (look for a DNSSEC option)               | Confirm DNSSEC is off for `sommerfeld.app` (no DS at `.app` on 2026-10-15). Do not enable it during the migration                                                                                                                                                                                                                                                                                                                              | DigitalOcean cannot sign, so a DS for `do` would break resolution                                                    | `curl -s 'https://dns.google/resolve?name=sommerfeld.app&type=DS'` has no `Answer`                                                                                                     | read-only                                                                                                          |
| M10 | during                                   | KAS → Tools → DNS-Einstellungen → `sommerfeld.app` → "Neuen DNS-Eintrag" | Create three records: Name `do`, Type `NS`, Prio `0`, Data `ns1.digitalocean.com.`; then the same with `ns2.digitalocean.com.` and `ns3.digitalocean.com.`. **The trailing dot is required** ([all-inkl tutorial](https://all-inkl.com/en/support/tutorials/kas/tools/dns-tools/how-to-change-the-name-servers-for-a-subdomain_155.html)). Leave the A record `fantasy-hockey.prod.do` in place. all-inkl says changes take up to 3 to 4 hours | moves authority for `do` and below to DigitalOcean                                                                   | M11                                                                                                                                                                                    | repeat-safe (the same records). No outage: both sides answer the same IP. Rollback R1: delete the three NS records |
| M11 | after M10, repeat until green            | devcontainer                                                             | `task cloud:dns:check -- +norec @ns5.kasserver.com fantasy-hockey.prod.do.sommerfeld.app A` (and `@ns6`), `task cloud:dns:check -- +trace fantasy-hockey.prod.do.sommerfeld.app`, then the DoH `NS do.sommerfeld.app` check at Google and Cloudflare                                                                                                                                                                                           | confirms the parent refers and the public sees the DigitalOcean nameservers                                          | the first AC of this story. Public NS can lag by up to 7200 s (a cached wildcard)                                                                                                      | read-only. Red after 4 h → R1                                                                                      |
| M12 | after M11                                | outside the home network (mobile data), and the devcontainer             | `curl -sI https://fantasy-hockey.prod.do.sommerfeld.app/`, `/login`, `http://…` redirect, `/metrics` 404; `echo \| openssl s_client -connect fantasy-hockey.prod.do.sommerfeld.app:443 -servername fantasy-hockey.prod.do.sommerfeld.app 2>/dev/null \| openssl x509 -noout -issuer -enddate`; the DoH CAA check                                                                                                                               | the service and the certificate are unaffected                                                                       | the HTTPS AC; issuer Let's Encrypt and expiry `Jan 13 18:13:07 2027 GMT` (or later, after a renewal)                                                                                   | read-only. Red → R1                                                                                                |
| M13 | after M12                                | calendar                                                                 | Wait at least 4 hours (2 × the KAS TTL of 7200 s) after M10, ideally 24 h, and repeat M11 and M12 once at the end                                                                                                                                                                                                                                                                                                                              | every resolver has expired the KAS answers and asks DigitalOcean                                                     | still green                                                                                                                                                                            | none                                                                                                               |
| M14 | after M13                                | KAS → Tools → DNS-Einstellungen → `sommerfeld.app`                       | Delete the A record `fantasy-hockey.prod.do` (value `129.212.195.118`). Touch nothing else                                                                                                                                                                                                                                                                                                                                                     | it is occluded by the delegation, and a stale copy at the KAS would mislead the next operator                        | `@ns5.kasserver.com` still refers; public A still the reserved IP; KAS list = M7 baseline minus the A record plus the three NS records                                                 | repeat-safe. Outage only if the delegation is broken, which M11 to M13 excluded. Rollback R3                       |
| M15 | after M14                                | devcontainer                                                             | Optional: `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` (vault password)                                                                                                                                                                                                                                                                                                                                                            | proves the deploy guard on the droplet resolver sees the DigitalOcean answer                                         | the play passes "Stop when the domain does not resolve to the reserved IP"                                                                                                             | idempotent. It may restart nothing                                                                                 |
| M16 | after M14                                | devcontainer                                                             | Report M7 to M15 outputs to the agent. Close Epic 7 retro items 26 (CAA, now in the DigitalOcean zone) and 27 (decided: yes) in `sprint-status.yaml`, or tell the agent to                                                                                                                                                                                                                                                                     | traceability                                                                                                         | the items are `done` with a reference to Epic 8                                                                                                                                        | N/A                                                                                                                |

**Rollback and recovery:**

- **R1, the delegation is broken (after M10, before M14):** delete the three NS records `do` in the KAS. The old A record still exists, so the KAS answers again at once. Resolvers that cached the DigitalOcean NS records keep asking DigitalOcean until the NS TTL expires (up to 7200 s for the parent's NS records), and DigitalOcean still answers correctly. **Keep the DigitalOcean zone.**
- **R2, a wrong record at DigitalOcean (any time):** fix it in `dns.tf` and run `plan`, review, `apply`. The fix is visible after the record TTL (300 s). For an urgent fix before review, the control panel works too, but the next `plan` shows the drift and must be reconciled. If the zone is deleted outside OpenTofu, `apply` recreates it with the same nameservers, and the KAS needs no change.
- **R3, a failure after M14:** recreate the A record in the KAS (Name `fantasy-hockey.prod.do`, Type `A`, Data the reserved IP), then do R1.
- **R4, state lost or corrupt:** restore the M3 backup. If there is no backup: `tofu import 'digitalocean_domain.this' do.sommerfeld.app` and `tofu import 'digitalocean_record.a["<name>"]' do.sommerfeld.app,<id>` (IDs from `doctl compute domain records list do.sommerfeld.app`).

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

**Why this order:** delegation is safe to add while the occluded A record still exists. Answers are identical, so caching, propagation or a resolver on either side cannot produce a wrong address. Deleting the A record first would expose the wildcard (`85.13.131.235`) for up to 7200 s to anyone who has not yet seen the NS records. That breaks HTTPS and could make a Caddy renewal fail validation. OpenTofu plays no part in the cutover: the KAS has no OpenTofu provider here, so a successful `apply` completes nothing beyond the DigitalOcean side.

**The parent zone stays untouched outside `do`:** the NS records sit at the name `do`. The wildcard `*.sommerfeld.app` keeps matching every other missing name, including `x.sommerfeld.app`. By DNS rules it no longer matches anything at or below the delegation point.

**Open questions:**

- Does the KAS accept NS records at `do` while the A record `fantasy-hockey.prod.do` exists below it? Does it answer that A record authoritatively anyway (occluded data)? Answer: M10 and M11. If it serves the occluded record, the delegation only becomes effective for that name at M14, and M14 must then be preceded by a short check window. Ask all-inkl support before M10, if you prefer.
- Does the KAS let you set the TTL of the NS records? Assumed 7200 like every other KAS record.
- `do.sommerfeld.app` should hold only DigitalOcean-hosted names (`docs/cloud/domain-naming.md`: `do` = DigitalOcean). Should other providers (`linode`, `aws`, `gcp`) later get their own delegated label in the same way? This is out of scope here, but the runbook is written so that it can be reused.
- Story 5.2 (synthetic check) is unaffected, because the hostname does not change. Should it be built after this epic, so its baseline starts on the final DNS path?

## Verification

**Commands (agent):**

- `task lint`: passes.
- `git grep -n -i -E "by hand at all-inkl|domain. is not needed|outside OpenTofu|dig \+short" -- docs configs-cloud`: no hits that describe the current state.
- The diagram syntax check: no errors.
- The read-only baseline from Tasks: recorded.

**Manual checks:** M7 to M16 above. The agent does not claim that live delegation, public resolution or HTTPS has been verified until the operator reports it.
