---
date: 2026-10-15
trigger: story-5-2-public-url
mode: incremental
scope: moderate
status: approved
approved: 2026-10-15
---

# Sprint Change Proposal: HTTPS on a Custom Domain Before Story 5.2

## 1. Issue Summary

The fantasy hockey app is reachable only at `http://129.212.195.118`, the droplet's reserved IP. The operator wants it at a fixed domain, `https://fantasy-hockey.prod.do.sommerfeld.io`, and only there, before the synthetic check of Story 5.2 is built, so that the check probes the domain instead of the IP.

- **Type:** re-prioritization of a planned requirement. HTTPS on a custom domain is already in the spec as CAP-9 (E6), but scheduled after GitHub Actions (E5), and the spec lists "HTTPS or a custom domain before E6" as a non-goal.
- **Discovered:** on 2026-10-15, after Story 5.1 (dashboard) was done, while planning Story 5.2, whose acceptance criterion probes `http://<reserved-ip>`.
- **Decisions by the operator:**
    - Move all of E6 (domain, HTTPS, Caddy replacing nginx), not the domain alone.
    - Hostname `fantasy-hockey.prod.do.sommerfeld.io`.
    - DNS stays with the web hosting provider all-inkl.com; the record is created by hand.
    - Once HTTPS works, only the domain serves the app; `http://<reserved-ip>` no longer does.

## 2. Impact Analysis

### Epic Impact

| Epic                 | Impact                                                                                                                                  |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Epic 5               | Story 5.1 is done and unchanged. Story 5.2 waits for Epic 7 and probes the domain over HTTPS, including a certificate check.            |
| Epic 7 (new, spec E6) | HTTPS on a custom domain: Story 7.1 DNS record, Story 7.2 Caddy with automatic TLS replaces nginx. Runs after 5.1, before 5.2 and Epic 6. |
| Epic 6               | No change. DNS is not at DigitalOcean, so there are no new secrets and no `domain` token scope.                                        |
| Spec E7, E8          | Not broken down yet. E7's post-deploy smoke test of the public URL targets the domain from now on. E8 is unaffected.                   |

### Story Impact

- **Story 5.2:** the acceptance criterion changes from `http://<reserved-ip>` to `https://fantasy-hockey.prod.do.sommerfeld.io`, plus a certificate validity check.
- **Story 7.1 (new):** A record at all-inkl.com, docs page, `dig` check.
- **Story 7.2 (new):** Caddy replaces nginx, certificates on the volume, a guard against failed certificate requests, Molecule and docs updates.

### Artifact Conflicts

- **SPEC (`spec-fantasy-hockey-digitalocean/SPEC.md`):** CAP-9 success text, epic order, new DNS constraint.
- **Spec `epics.md`:** delivery order and the E6 section; the `sslip.io` fallback is obsolete.
- **Architecture spine:** `binds` covers CAP-9; AD-10 gets a DNS bullet (manual record outside OpenTofu, certificates on the volume).
- **`epics-fantasy-hockey-digitalocean.md`:** overview, FR9, coverage map, epic list, Epic 7 section, Story 5.2.
- **PRD:** not affected; it governs the homelab fleet.
- **UX:** none exists; not needed.

### Technical Impact

- The compose project of the `fantasy-hockey` role swaps nginx for Caddy (ports 80 and 443); the app stays on `127.0.0.1:8080`, so the Alloy scrape and the dashboard keep working. The dashboard's `container` variable picks up the new container by itself.
- Certificates and the ACME account live on the volume, so a droplet replacement reuses them and does not run into Let's Encrypt rate limits.
- The domain points at the reserved IP, which survives a replacement, so no DNS change is needed then.
- The Dependabot compose entry for the role covers the Caddy image without a change.
- Docs under `docs/cloud/digital-ocean` (deployment, replacement, overview, monitoring, a new domain page) change inside the stories.

## 3. Recommended Approach

**Direct adjustment:** add Epic 7 with two stories and adjust the planning docs; no rollback, no scope change.

- **Effort:** low to medium (one manual DNS step, one role change with tests and docs).
- **Risk:** low. The main risk is the first certificate request; Story 7.2 guards it by stopping the deploy when the domain does not resolve.
- **Timeline:** Epic 7 is inserted before Story 5.2 and Epic 6; nothing already done is reworked.
- **Alternatives considered:** domain only over HTTP (rejected: TLS would follow soon and redo the work); domain with nginx and certbot (rejected: CAP-9 already decided on Caddy).

## 4. Detailed Change Proposals

### SPEC

**`SPEC.md`, CAP-9:**

```
OLD:
    - **success:** `https://fantasy-hockey.do.sommerfeld.io` (or `do.sommerfeld.io/fantasy-hockey`) serves the app with an automatically renewed certificate via Caddy, which replaces nginx; the app is published only on `127.0.0.1:8080`.

NEW:
    - **success:** `https://fantasy-hockey.prod.do.sommerfeld.io` (pattern `<app>.<stage>.do.sommerfeld.io`) serves the app with an automatically renewed certificate via Caddy, which replaces nginx; only that domain serves the app, so `http://<reserved-ip>` no longer does; the app is published only on `127.0.0.1:8080`; the certificates live on the volume and survive a droplet replacement.
```

Rationale: fixes the chosen hostname, drops the path variant, adds domain-only serving and certificate persistence.

**`SPEC.md`, Constraints:**

```
OLD:
- Epic order is E1 droplet, E2 provisioning, E3 deploy, E4 dashboard, E5 GitHub Actions (a Must, fifth), E6 HTTPS, E7 hardening, E8 backup last. Everything runs locally via go-task before CI is built. Details in `epics.md`.

NEW:
- Epic order is E1 droplet, E2 provisioning, E3 deploy, E4 dashboard (the dashboard first, the synthetic check after E6), E6 HTTPS, E5 GitHub Actions (a Must), E7 hardening, E8 backup last. E6 moved before the synthetic check and E5 on 2026-10-15, so the check probes the domain, not the IP. Everything runs locally via go-task before CI is built. Details in `epics.md`.
- DNS for `sommerfeld.io` stays with the web hosting provider all-inkl.com. The A record `fantasy-hockey.prod.do.sommerfeld.io` pointing at the reserved IP is created by hand there and documented; OpenTofu does not manage DNS, and the DigitalOcean token needs no `domain` scope.
```

Rationale: records the new order with its reason and the DNS decision in the canonical contract.

**Spec `epics.md`, delivery table and E6:**

```
OLD:
| E4   | Grafana dashboard            | Should          | CAP-4        |
| E5   | GitHub Actions               | Must            | CAP-5        |
| E6   | HTTPS, domain, Caddy         | Could           | CAP-9        |

NEW:
| E4   | Grafana dashboard            | Should          | CAP-4        |
| E6   | HTTPS, domain, Caddy         | Should          | CAP-9        |
| E5   | GitHub Actions               | Must            | CAP-5        |
```

New sentence under the table: `E6 runs between the E4 dashboard and the E4 synthetic check (re-prioritized 2026-10-15), so the check probes the domain.`

```
OLD:
- Custom domain, Caddy with automatic TLS replacing nginx, app on `127.0.0.1:8080`.
- Fallback if no domain: `<ip>.sslip.io`.

NEW:
- Domain `fantasy-hockey.prod.do.sommerfeld.io` (pattern `<app>.<stage>.do.sommerfeld.io`): A record to the reserved IP, created by hand at all-inkl.com and documented.
- Caddy with automatic TLS replaces nginx and serves only that domain; the app stays on `127.0.0.1:8080`; certificates on the volume.
```

Rationale: the table is the delivery order; E6 rises from Could to Should because it now precedes a Must. The `sslip.io` fallback is obsolete.

### Architecture

**`ARCHITECTURE-SPINE.md`:** frontmatter `binds` `'CLOUD-CAP-1..CAP-8'` becomes `'CLOUD-CAP-1..CAP-9'`. New AD-10 bullet after "Accepted risks":

```
    - **DNS:** DNS is not part of the declaration. The domain `sommerfeld.io` stays with the web hosting provider all-inkl.com, and each cloud app's A record (`<app>.<stage>.do.sommerfeld.io` → the droplet's reserved IP) is kept there by hand and documented under `docs/cloud/`. Because the record points at the reserved IP, it survives a droplet replacement. TLS certificates are issued on the droplet (Caddy, automatic) and kept on the volume, not in OpenTofu state.
```

Rationale: makes the manual DNS record a deliberate exception to "OpenTofu declares the cloud resources".

### Epics and Stories

**`epics-fantasy-hockey-digitalocean.md`, Overview:**

```
OLD:
The spec's E6 (HTTPS), E7 (hardening) and E8 (backup) get their own breakdown later and are not in this file.

NEW:
The spec's E6 (HTTPS) is Epic 7 here; it was pulled forward on 2026-10-15 and runs after Story 5.1 and before Story 5.2 and Epic 6. The spec's E7 (hardening) and E8 (backup) get their own breakdown later and are not in this file.
```

New requirement after FR8: `FR9: Users reach the app over HTTPS at `fantasy-hockey.prod.do.sommerfeld.io`, and only there, with automatically renewed certificates. (SPEC CAP-9)`

New coverage line: `FR9: Epic 7 - DNS record and Caddy with automatic TLS`

New epic list entry between Epic 5 and Epic 6:

```
### Epic 7: HTTPS on a custom domain
The app is served only at `https://fantasy-hockey.prod.do.sommerfeld.io` through Caddy with automatic TLS. Runs after Story 5.1 and before Story 5.2 and Epic 6.
**FRs covered:** FR9, FR7
```

Rationale: "Epic 7" keeps numbering unique without renumbering Epic 6; the run order is stated in text and in sprint status.

**New Epic 7 section** (between Epic 5 and Epic 6):

```markdown
## Epic 7: HTTPS on a custom domain

The app is served only at `https://fantasy-hockey.prod.do.sommerfeld.io` through Caddy with automatic TLS. Runs after Story 5.1 and before Story 5.2 and Epic 6.

### Story 7.1: DNS record for the droplet

As an operator,
I want a fixed domain that points at the droplet,
So that users reach the app by name instead of by IP.

**Acceptance Criteria:**

**Given** the reserved IP from `tofu output reserved_ip_addresses`
**When** the A record `fantasy-hockey.prod.do.sommerfeld.io` is created by hand at all-inkl.com
**Then** `dig +short fantasy-hockey.prod.do.sommerfeld.io` returns the reserved IP from outside the home network
**And** a docs page under `docs/cloud/digital-ocean` describes the record, the hostname pattern `<app>.<stage>.do.sommerfeld.io`, the manual steps at all-inkl.com and the check, and says that a droplet replacement needs no DNS change

### Story 7.2: Caddy with automatic TLS replaces nginx

As a user,
I want the app over HTTPS at its domain,
So that the connection is encrypted and the address does not change.

**Acceptance Criteria:**

**Given** the DNS record from Story 7.1
**When** the deploy runs
**Then** a Caddy container replaces nginx in the compose project, listens on ports 80 and 443, obtains and renews the certificate for `fantasy-hockey.prod.do.sommerfeld.io` automatically, and proxies to the app on `127.0.0.1:8080`
**And** the domain is derived from the droplet's stage and app name, not hard-coded per host
**And** `https://fantasy-hockey.prod.do.sommerfeld.io` serves the app, `http://` on the domain redirects to `https://`, `/metrics` returns 404, and `http://<reserved-ip>` no longer serves the app

**Given** the Caddy data folder (certificates and ACME account) on the volume
**When** the droplet is replaced
**Then** the new droplet reuses the stored certificate instead of requesting a new one

**Given** the domain does not resolve
**When** the deploy runs
**Then** it stops with a clear message before Caddy starts, so no certificate requests fail against Let's Encrypt's rate limits

**Given** the change
**When** it is done
**Then** the nginx files are gone from the droplet, the `fantasy-hockey` Molecule scenario checks the Caddyfile instead of `nginx/default.conf`, Dependabot bumps the Caddy image through the existing compose entry, and the docs (deployment, replacement checks, overview diagram, monitoring) name Caddy and the domain
```

Rationale: 7.1 is the manual prerequisite (Caddy needs a resolving name); 7.2 carries the technical change with guards against the most likely failure, Let's Encrypt rate limits.

**Story 5.2, Acceptance Criteria:**

```
OLD:
**Given** the existing Grafana Cloud synthetic monitoring
**When** the check runs
**Then** it probes `http://<reserved-ip>` from outside, like the existing checks from Frankfurt and Paris

NEW:
**Given** the existing Grafana Cloud synthetic monitoring and the domain from Epic 7
**When** the check runs
**Then** it probes `https://fantasy-hockey.prod.do.sommerfeld.io` from outside, like the existing checks from Frankfurt and Paris
**And** it fails when the certificate is invalid or expires within 14 days
```

Rationale: after Epic 7 the IP no longer serves the app; the certificate check catches a broken renewal early and is a probe, not an alert rule.

### Sprint Status

**`implementation-artifacts/sprint-status.yaml`:**

```
OLD:
  epic-5: in-progress
  5-1-grafana-dashboard-for-the-droplet-and-the-app: done
  5-2-synthetic-monitoring-check-for-the-public-url: backlog
  epic-5-retrospective: optional

  epic-6: backlog

NEW:
  epic-5: in-progress
  5-1-grafana-dashboard-for-the-droplet-and-the-app: done
  # 5.2 waits for Epic 7: it probes the domain (sprint-change-proposal-2026-10-15)
  5-2-synthetic-monitoring-check-for-the-public-url: backlog
  epic-5-retrospective: optional

  # Epic 7 runs before Story 5.2 and Epic 6 (sprint-change-proposal-2026-10-15)
  epic-7: backlog
  7-1-dns-record-for-the-droplet: backlog
  7-2-caddy-with-automatic-tls-replaces-nginx: backlog
  epic-7-retrospective: optional

  epic-6: backlog
```

`last_updated` is set from `date`.

## 5. Implementation Handoff

**Scope: moderate** (backlog reorganization with a new epic; no replan).

| Who                | Responsibility                                                                                                                          |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Developer agent    | Apply the planning edits above and the sprint-status entries in this workflow run; then build Story 7.2 with `bmad-build`.               |
| Operator (user)    | Story 7.1: create the A record at all-inkl.com; run the deploy for Story 7.2 (vault password); confirm the HTTPS checks from outside.   |
| Developer agent    | Story 7.1 docs page and the `dig` check once the record exists; Story 5.2 after Epic 7, probing the domain.                             |

**Success criteria:**

- `https://fantasy-hockey.prod.do.sommerfeld.io` serves the app with a valid certificate; `http://<reserved-ip>` no longer serves it.
- A droplet replacement keeps the domain and the certificate without a DNS change or a new certificate request.
- Story 5.2's synthetic check probes the domain over HTTPS.
- The planning docs (SPEC, spec epics, spine, epics file) and `sprint-status.yaml` agree on the new order.
