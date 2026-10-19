---
title: 'Story 7.2: Caddy with automatic TLS replaces nginx'
type: 'feature'
created: '2026-10-15'
status: 'done'
route: 'dispatch'
baseline_commit: '1cbf9d1f1c84c2a02dd928c35f6815afcd3cc1e2'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The app is served over plain HTTP by nginx at `http://<reserved-ip>`. The `.app` domain from Story 7.1 cannot be opened in a browser (HSTS preload), and traffic is unencrypted.

**Approach:** In the `fantasy-hockey` compose project, a pinned `caddy` container replaces nginx on ports 80 and 443 (plus 443/udp for HTTP/3). It gets a Let's Encrypt certificate for `<app>.<stage>.do.sommerfeld.app` (derived from the droplet name `<stage>-<app>`), stores it on the volume, serves only that name, and answers `/metrics` with 404. Before anything is written, the deploy checks from the droplet that the domain resolves to the droplet's reserved IP (read from the DigitalOcean metadata service). The nginx container and files are removed.

## Boundaries & Constraints

**Always:** The app stays published only on `127.0.0.1:8080`, so Alloy and the dashboard keep working. Caddy's `/data` and `/config` live under `fantasy_hockey_path` on the volume (covered by the existing `RequiresMountsFor=` drop-in). The DNS guard compares against the reserved IP, not "resolves at all": the `sommerfeld.app` wildcard makes every missing name resolve to `85.13.131.235`. Molecule containers stay unprivileged, no systemd, no host mounts.

**Never:** No DigitalOcean firewall, no DNS in OpenTofu, no ACME email or staging CA switch, no nginx/certbot, no per-host hard-coded domain.

## I/O & Edge-Case Matrix

| Scenario              | Input / State                                 | Expected Output / Behavior                                   | Error Handling                                              |
|-----------------------|-----------------------------------------------|--------------------------------------------------------------|-------------------------------------------------------------|
| HTTPS on the domain   | `https://<domain>/`                           | App responds, valid Let's Encrypt certificate                | N/A                                                         |
| HTTP on the domain    | `http://<domain>/x?y=1`                       | 308 to `https://<domain>/x?y=1`                              | N/A                                                         |
| Reserved IP           | `http://<reserved-ip>/`                       | 404 from Caddy, app not served                               | `https://<reserved-ip>` fails the TLS handshake             |
| Metrics hidden        | `/metrics`, `/METRICS/`, `//metrics` on HTTPS | 404, not forwarded                                           | N/A                                                         |
| Domain missing/wrong  | Domain resolves to wildcard IP or nothing     | Deploy stops before anything is written, names domain and IP | Message points at `docs/cloud/digital-ocean/domain.md`      |
| Upgrade from nginx    | Old stack with `fantasy-hockey-nginx` running | Orphan removed, port 80 freed, `nginx/` folder deleted       | N/A                                                         |
| Droplet replacement   | Certificate already in `caddy/data` on volume | Reused, no new ACME order                                    | N/A                                                         |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml` -- play vars derive volume paths from `inventory_hostname` (`prod-fantasy-hockey`); add domain derivation there the same way, and a metadata read of the reserved IP before `include_role`.
- `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/{defaults/main.yml,files/docker-compose.yml,tasks/main.yml,tasks/files.yml,README.md}` -- role; `files/nginx/default.conf` goes away. `main.yml` guards → user → files → compose; asserts per container.
- `configs-cloud/digital-ocean/tests/molecule/fantasy-hockey/molecule/default/{converge,verify}.yml`, `vars/test-vars.yml` -- scenario runs `tasks_from: user`/`files` and guard cases with `/etc/hostname` as fake mount.
- `docs/cloud/digital-ocean/{deployment,replacement,index,monitoring,tests,domain,provisioning,tasks-and-linters}.md`, `docs/pipelines.md:109` -- name nginx / `http://<reserved-ip>`.
- `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json:1905` -- 5xx panel description names nginx.
- `.github/dependabot.yml` -- docker-compose entry on the role's `files/` already covers the new image; no change.

## Tasks & Acceptance

**Execution:**

- [x] `.../roles/fantasy-hockey/defaults/main.yml` -- add `fantasy_hockey_domain: fantasy-hockey.prod.do.sommerfeld.app` (prod default, like the volume mount) -- playbook overrides it.
- [x] `.../playbooks/deploy-fantasy-hockey.yml` -- vars: `fantasy_hockey_domain` = `<app>.<stage>.do.sommerfeld.app` from `inventory_hostname.split('-', 1)`; task: `uri` `http://169.254.169.254/metadata/v1/reserved_ip/ipv4/ip_address` into `fantasy_hockey_reserved_ip` (fail clearly when no reserved IP is assigned); update header comment (Caddy).
- [x] `.../roles/fantasy-hockey/tasks/dns.yml` (new) -- `getent ahostsv4 {{ fantasy_hockey_domain }}` (`failed_when: false`, `changed_when: false`), assert `fantasy_hockey_reserved_ip` is among the addresses; `fail_msg` names domain, found addresses, expected IP and `domain.md`. Included from `main.yml` right after the two volume guards.
- [x] `.../roles/fantasy-hockey/templates/Caddyfile.j2` (new) -- site `{{ fantasy_hockey_domain }}` with `log`, `@metrics path_regexp (?i)^/+metrics/*$` → `respond 404`, `reverse_proxy app:8080`; plus `http:// { respond 404 }` catch-all (prototype verified: domain still redirects, IP gets 404).
- [x] `.../roles/fantasy-hockey/files/docker-compose.yml` -- replace `nginx` with `caddy` (`caddy:2.11.7`, container `${COMPOSE_PROJECT_NAME}-caddy`, ports `80:80`, `443:443`, `443:443/udp`, volumes `./caddy/Caddyfile:/etc/caddy/Caddyfile:ro`, `./caddy/data:/data`, `./caddy/config:/config`); fix app comment.
- [x] `.../roles/fantasy-hockey/tasks/files.yml` -- create `caddy/`, `caddy/data`, `caddy/config` (data/config `0700`); template Caddyfile (register `fantasy_hockey_caddyfile`); remove `{{ fantasy_hockey_path }}/nginx` (`state: absent`); delete `files/nginx/`.
- [x] `.../roles/fantasy-hockey/tasks/main.yml` -- `remove_orphans: true` on the compose up; restart condition uses the Caddyfile; read/assert `fantasy-hockey-caddy` instead of nginx.
- [x] Molecule scenario -- test vars `fantasy_hockey_domain: localhost`, `fantasy_hockey_reserved_ip: 127.0.0.1`; converge also runs `tasks_from: dns` (pass case); verify: Caddyfile/caddy dirs owners and modes, Caddyfile contains the domain, a pre-created `nginx/default.conf` is gone after re-running `files`, and a guard case (path below `/etc/hostname`, reserved IP `192.0.2.1`) stopped by the DNS guard with no user created.
- [x] Docs, role README, dashboard description -- replace nginx/HTTP with Caddy/HTTPS/domain: deployment (files table, checks, cert on volume, DNS guard), replacement checks (HTTPS, cert reused), index diagram (`HTTPS :443` via domain), monitoring (Caddy 502s), tests table, domain (HTTPS now served, guard), provisioning cAdvisor line, pipelines, tasks-and-linters example; then `task docs:generate`.

**Acceptance Criteria:**

- Given the role, when `task cloud:molecule:test:fantasy-hockey` runs, then it passes with the new Caddy, nginx-removal and DNS-guard checks.
- Given the change, when `task lint` runs, then it passes.
- Given the operator deploys, when checks run from outside, then the I/O matrix holds, `docker compose ps` lists `fantasy-hockey-app` and `fantasy-hockey-caddy`, a second deploy reports `changed=0`, and `up{job="fantasy-hockey"}` stays 1.

## Implementation Notes

- `Caddyfile.j2` is indented with tabs (the `caddy fmt` style; Caddy warns at start about other indentation). `.editorconfig` got a `[Caddyfile.j2] indent_style = tab` section for it.
- `caddy/data` and `caddy/config` are owned by `default_user` with `0700`; Caddy runs as root in its container and writes there regardless.
- The playbook asserts the metadata answer is HTTP 200 and an IPv4 address (DigitalOcean answers 404 without a reserved IP).
- Verified locally: rendered Caddyfile `caddy validate` OK and `caddy fmt --diff` clean; a routing smoke test (`caddy:2.11.7` with `local_certs`, stand-in app on `app:8080`) gave 200 on `/`, 404 on `/metrics`, `/METRICS/`, `//metrics`, 200 on `/metricsx`, 308 to `https://<domain>/x?y=1`, 404 on `http://<ip>/`, TLS failure on `https://<ip>/`.
- Matrix coverage: "Domain missing/wrong" and the `nginx/` folder half of "Upgrade from nginx" run in the Molecule scenario. The four routing rows and orphan removal (`compose up --remove-orphans` freeing the port) were checked by one-off local Docker runs, not a registered test: Molecule cannot run Docker. "Droplet replacement" and all rows on the real droplet are operator checks after the deploy.

- Operator deploy 2026-10-15: from outside, `http://` on the domain 308 to `https://`, `/metrics` 404, `http://129.212.195.118/` 404, `https://129.212.195.118/` TLS alert; `docker compose ps` lists `fantasy-hockey-app` and `fantasy-hockey-caddy` (nginx orphan removed, port 80 freed), no `nginx/` folder; `up{job="fantasy-hockey"}` is 1; certificate issued by Let's Encrypt (YE1), expires 2027-01-13. `https://<domain>/` answers 302 to `/login` (the app's own redirect, on `https://`, so the app sees the scheme); the docs' check expected 200 and now checks `/` for 302 and `/login` for 200.

## Spec Change Log

## Review Triage Log

Blind Hunter (13), Edge Case Hunter (6), Verification Gap (2 gaps + 1 other):

- medium, patch — Caddyfile only checked for site line and `reverse_proxy` (BH, VG gap 1): dropping the `/metrics` 404 or the `http://` catch-all would pass lint and Molecule; verify now asserts both blocks.
- low, patch — DNS guard checks membership, not equality (BH, ECH): a stale second A record passes the guard while Let's Encrypt may validate the other address; now requires exactly the reserved IP.
- low, patch — `--check` runs break the getent and metadata reads (ECH ×2): `command` is skipped in check mode, leaving no `stdout_lines`; both read-only tasks get `check_mode: false`.
- low, patch — metadata unreachable reported as "no reserved IP" (BH): `failed_when: false` turns a timeout into status -1; timeout set and message names both causes.
- low, patch — docs check commands imprecise (BH): `curl -sI` prints headers, not `200`; `grep -c` exits 1 on 0 matches over ssh.
- medium, defer — compose orchestration and playbook pre-tasks run only on the droplet (VG gap 2): `remove_orphans`, restart on Caddyfile change, container asserts and the domain derivation have no automated test; Molecule cannot run Docker without a privileged container.
- false — `/metrics` bypass via dot segments (BH): checked with `caddy:2.11.7` and `--path-as-is`: `/x/../metrics`, `/./metrics`, `/metrics/.`, `/metrics%2F`, `/%6detrics` all 404; `/metrics;x` reaches the app exactly as it did under the nginx regex.
- false — app must learn it runs behind HTTPS (BH): the app's documented config has no base URL, secure-cookie or proxy setting, and login mails carry a 6-digit code, not a link.
- false — certificate and proxy health not monitored (BH): Story 5.2 (synthetic HTTPS check with 14-day expiry) is the planned owner, per the epic context.
- false — single-file Caddyfile bind mount keeps the old inode (BH): the role restarts the stack on a Caddyfile change, and Docker re-resolves bind sources on every container start.
- rejected low — `nginx/` removed before `compose up`, and no rollback path (ECH, BH): a one-time, operator-attended migration; failure needs a compose failure plus a reboot before the next deploy, and moving the task loses its Molecule coverage.
- rejected low — whole stack restarts on Caddyfile change, double restart on the migration run (BH ×2): same pattern nginx had; Caddy's storage locks make a repeated start resume the ACME order.
- rejected low — domain derivation unvalidated for names without a dash (BH): every wrong domain is stopped by the DNS guard before anything is written.
- rejected low — "resolves to nothing" case untested (BH): the zone wildcard makes an empty answer unreachable in practice; the mismatch case covers the guard.
- rejected low — `caddy/` dirs owned by `fantasy-hockey` while Caddy writes as root (BH): documented in `files.yml` and `deployment.md`; no current consumer reads them as the deploy user.
- rejected low — "before anything is written" while the volume mount and drop-in precede the guard (ECH): those writes are the existing volume step and harmless; the role writes nothing before the guard.
- rejected low — Caddy JSON logs replace nginx combined lines (ECH): no Loki, Alloy or dashboard query in the repo parses the old format.
- rejected low — guard-folder loop omits the DNS case path (VG other): `/etc/hostname` is a file, so nothing can be created below it; the `fh-guard-dns` user assert covers the order.

## Design Notes

- Caddy proxies to the app over the compose network (`app:8080`) as nginx did; the app's `127.0.0.1:8080` host binding stays for Alloy. Caddy resolves the upstream per connection, so no nginx-style `resolver` workaround is needed.
- No ACME email: Let's Encrypt no longer sends expiry mails; Story 5.2 watches expiry.
- Prototype in the devcontainer (`caddy:2.11.7`, `local_certs`) confirmed every routing row of the matrix, and `compose up --remove-orphans` removes the old container before binding the freed port.

## Verification

**Commands:**

- `task cloud:molecule:test:fantasy-hockey` -- expected: passes
- `task lint` -- expected: passes
- `docker run --rm -v <role>/templates/...:... caddy:2.11.7 caddy validate` on a rendered Caddyfile -- expected: valid

**Manual checks (operator, after deploy):**

- `curl -sI https://fantasy-hockey.prod.do.sommerfeld.app` 200; `curl -sI http://fantasy-hockey.prod.do.sommerfeld.app` 308; `curl -s -o /dev/null -w '%{http_code}' https://fantasy-hockey.prod.do.sommerfeld.app/metrics` 404; `curl -s -o /dev/null -w '%{http_code}' http://129.212.195.118/` 404.
