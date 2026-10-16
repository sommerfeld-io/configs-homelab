# Epic 7 Context: HTTPS on a custom domain

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Serve the fantasy hockey app only at `https://fantasy-hockey.prod.do.sommerfeld.app`, with certificates that Caddy obtains and renews automatically, in place of the current plain-HTTP nginx at the droplet's reserved IP. The operator wants a fixed, encrypted address and no exposure by IP. This epic was moved forward on 2026-10-15: it runs after Story 5.1 (dashboard) and before Story 5.2 (synthetic check) and Epic 6 (GitHub Actions), so the synthetic check can probe the domain over HTTPS instead of the IP.

## Stories

- Story 7.1: DNS record for the droplet
- Story 7.2: Caddy with automatic TLS replaces nginx

## Requirements & Constraints

- Hostname pattern is `<app>.<stage>.do.sommerfeld.app`; the first instance is `fantasy-hockey.prod.do.sommerfeld.app`. Derive the domain from the droplet's stage and app name, never hard-code it per host.
- Once HTTPS works, only the domain serves the app: `http://` on the domain redirects to `https://`, `http://<reserved-ip>` no longer serves the app, and `/metrics` returns 404 from outside.
- The app stays published only on `127.0.0.1:8080`, so the Alloy scrape of `:8080/metrics` and the existing dashboard keep working. The dashboard's `container` variable picks up the new Caddy container without changes.
- Certificates and the ACME account must survive a droplet replacement: a new droplet reuses the stored certificate rather than requesting a new one (Let's Encrypt rate limits).
- The deploy must stop with a clear message before Caddy starts when the domain does not resolve, so no certificate request fails against Let's Encrypt.
- A droplet replacement needs no DNS change, because the record points at the reserved IP, which survives replacement.
- Verify from outside the home network: `dig +short` must return the reserved IP (from `tofu output reserved_ip_addresses`, not the droplet's own IP), and the HTTPS checks run from outside.
- Docs under `docs/cloud/digital-ocean` change in the same story: a new domain page (record, hostname pattern, manual steps at all-inkl.com, the `dig` check, no DNS change on replacement), plus deployment, replacement checks, overview diagram and monitoring pages naming Caddy and the domain.
- Remove the nginx files from the droplet. The `fantasy-hockey` Molecule scenario checks the Caddyfile instead of `nginx/default.conf`. Molecule containers stay unprivileged, with no systemd as PID 1 and no host mounts.
- Still in force: no DigitalOcean firewall, no user-data scripts, one droplet, budget about $6.20 per month.

## Technical Decisions

- **DNS is outside the declaration.** `sommerfeld.app` is hosted at all-inkl.com (nameservers `ns5`/`ns6.kasserver.com`). The operator creates the A record by hand there and it is documented. OpenTofu does not manage DNS, and the DigitalOcean token gets no `domain` scope. This is a deliberate exception to "OpenTofu declares the cloud resources". Epic 6 needs no new secrets because of it.
- **The `.app` TLD is on the browsers' HSTS preload list**, so browsers use HTTPS only. The DigitalOcean project keeps the name `sommerfeld.io`.
- **Caddy replaces nginx** inside the existing compose project of the `fantasy-hockey` role (under `configs-cloud/digital-ocean/ansible/roles`), listening on ports 80 and 443 and proxying to `127.0.0.1:8080`. nginx with certbot was rejected.
- **Caddy's data folder (certificates and ACME account) lives on the volume** next to the app data under `/mnt/prod_fantasy_hockey_data/`, not in OpenTofu state.
- **Image pinning:** the third-party Caddy image is pinned to a tag. The existing Dependabot compose entry for the role picks it up without changes.
- **Volume mount ordering:** the volume mounts with `nofail`, and the Epic 4 retro flagged that Docker could start before a late volume and create empty bind-mount paths on the root disk. A Caddy data folder on the volume has the same exposure, so it must follow whatever mount ordering the role already applies.

## Cross-Story Dependencies

- Story 7.1 must come before 7.2: Caddy needs a name that resolves before it can get a certificate. Story 7.1's manual step (creating the A record) is done by the operator. The agent writes the docs page and runs the `dig` check once the record exists.
- In Story 7.2 the operator runs the deploy (vault password) and confirms the HTTPS checks from outside.
- Story 5.2 (synthetic check) waits for this epic. It probes `https://fantasy-hockey.prod.do.sommerfeld.app` and fails when the certificate is invalid; its `TLSTargetCertificateCloseToExpiring` alert fires when the certificate expires within 14 days.
- Epic 6 (GitHub Actions) follows this epic and is otherwise unchanged. The later hardening epic's post-deploy smoke test targets the domain.
