---
title: 'Story 7.1: DNS record for the droplet'
type: 'feature'
created: '2026-10-15'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The app has no name: users reach it only at the reserved IP. The operator created the A record `fantasy-hockey.prod.do.sommerfeld.app` → `129.212.195.118` by hand at all-inkl.com on 2026-10-15, but nothing documents it, so a later operator cannot find, check or recreate it.

**Approach:** A docs page `docs/cloud/digital-ocean/domain.md` (in the `mkdocs.yml` nav and the Digital Ocean overview) describes the record, the hostname pattern `<app>.<stage>.do.sommerfeld.app`, why DNS stays at all-inkl.com outside OpenTofu, the manual steps in the KAS (Tools → DNS-Einstellungen, record name without the domain, not a KAS subdomain), the wildcard record it overrides, the check through a public DNS-over-HTTPS resolver against `tofu output reserved_ip_addresses`, and that a droplet replacement needs no DNS change. The record is checked from outside (Google and Cloudflare resolvers).

</frozen-after-approval>

## Implementation Notes

- Record checked 2026-10-15 from the devcontainer through public resolvers: `dns.google` and `cloudflare-dns.com` both answer `129.212.195.118`; `tofu -chdir=configs-cloud/digital-ocean/opentofu output -json reserved_ip_addresses` is `{"prod-fantasy-hockey":"129.212.195.118"}`; the operator's own check showed the answer comes from all-inkl's nameserver `85.13.128.3` with TTL 7200.
- `sommerfeld.app` uses `ns5`/`ns6.kasserver.com`, and a wildcard sends every other name to `85.13.131.235`.
- `dig` is not installed in the devcontainer, so the documented check uses `curl` against `dns.google`.
- Files: new `docs/cloud/digital-ocean/domain.md`; `mkdocs.yml` nav (Domain after Droplet); `docs/cloud/digital-ocean/index.md` (Domain bullet and Pages row); `api-token.md` (why `domain` scope is not needed); `replacement.md` (no DNS change on replacement). `task lint` passes.
- The page also explains why the name does not open in a browser before Story 7.2 (`.app` is HSTS-preloaded) and that there is no AAAA record (the reserved IP is IPv4 only).

## Review Triage Log

Blind Hunter, 11 findings:

- medium, patch — "a replacement needs no DNS change" overstated: a new region, `stage` or map key gives a new reserved IP or name (`droplet.md`); `domain.md` now says when the record must change.
- medium, patch — no retirement step: a record left on a released reserved IP points at an address DigitalOcean can reassign; added "Remove the Record".
- low, patch — `<app>` undefined: now the key of the `droplets` map (`fantasy-hockey`), same parts as the droplet name `<stage>-<app>`.
- low, patch — check used one resolver and "from outside the home network" was misleading: Google and Cloudflare queries, compare with `tofu output`, `85.13.131.235` explained, Fritz!Box cache named.
- low, patch — CAA state unrecorded: checked 2026-10-15, no CAA up to `sommerfeld.app`; documented with the `letsencrypt.org` requirement.
- low, patch — `api-token.md` sentence contradicted itself: split into two statements.
- low, patch — HSTS paragraph would go stale after Story 7.2: reworded so it holds before and after.
- low, patch — record TTL missing: 7200 added to the table.
- false — overview diagram, `index.md` "reachable over HTTP" and `deployment.md` not updated: those describe the HTTP/nginx path that Story 7.2 replaces, and its AC lists them; still true for 7.1.
- false — status `in-progress`: the workflow moves the story to `review` at finalize.
- rejected low — lowering the TTL before a planned IP change: the KAS sets the TTL; a reserved-IP change is rare and covered by the new "when the record must change" text.
