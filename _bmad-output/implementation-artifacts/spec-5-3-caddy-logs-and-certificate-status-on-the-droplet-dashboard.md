---
title: 'Story 5.3: Caddy logs and certificate status on the droplet dashboard'
type: 'feature'
created: '2026-10-15'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-5-1-grafana-dashboard-for-the-droplet-and-the-app.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-7-2-caddy-with-automatic-tls-replaces-nginx.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Since Story 7.2, Caddy sits in front of the app, but the dashboard `Apps / Fantasy Hockey / Droplet` cannot see it. Caddy's JSON logs already reach Loki (raw lines under `container="fantasy-hockey-caddy"`). Nothing separates access lines from operational lines and certificate events, nothing counts the 502s Caddy answers itself (the 5.1 review left this gap), and nothing shows the certificate's validity or Caddy's ACME activity.

**Approach:** Add no new collector. In the cloud Alloy config, a `loki.process` stage for the Caddy container parses the JSON line Caddy already writes and adds one low-cardinality label, `log_type` (`access`, `tls` or `operational`). A new dashboard row "Proxy" gets LogQL panels for requests by status, the 5xx rate as Caddy sees it (its own 502s included), p95 duration, top paths, the operational log and the certificate events. The certificate's days to expiry come from Story 5.2's synthetic check. Caddy masks client IPs before they are logged. The `monitoring.md` docs page gets the rows, LogQL examples and a PlantUML diagram of the flow.

**Decisions (human, 2026-10-15):**

- **`/monitoring`:** the app has no such endpoint. Release `0.1.1` and `main` of `sommerfeld-io/fantasy-hockey` register only the UI routes, `/login*`, `/logout`, `/static/` and `GET /metrics`, and the live domain answers `/monitoring` with 404. `/metrics` is the app's monitoring endpoint: it is already scraped (job `fantasy-hockey`) and charted (App row, App stat), so this story adds nothing for it and the docs say so.
- **Certificate expiry source:** Story 5.2's synthetic check. Caddy 2.11.7 exports no certificate metric. The stat "Certificate Expires In" reads `probe_ssl_earliest_cert_expiry - time()` for the 5.2 check's `job`, so 5.3 is built after 5.2, and there is no second probe.
- **Client IPs:** masked in the Caddyfile with `format filter` and `ip_mask` on `request>remote_ip` and `request>client_ip` (IPv4 /24, IPv6 /48; validated on `caddy:2.11.7`). The deploy restarts the stack once (a short outage).

## Boundaries & Constraints

**Always:**

- Reuse the existing Docker log source in `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`, with a processing stage between it and `loki.write`. Never add a second source for the same container: duplicate streams.
- Put new labels only into the cloud template, never into the fleet `config.alloy.j2`.
- `log_type` is the only new stream label. `uri`, `status`, `client_ip`, `duration` and `logger` stay in the line, parsed at query time with `| json`.
- Every Loki and Prometheus query keeps `environment="digital-ocean"` and `stage=~"$stage"`, except series that do not carry these labels (synthetic monitoring), which are filtered by their check's `job`/`instance` and documented as the exception.
- Match the Caddy logger names by prefix:
    - `^http\.log\.access` is `access`: Caddy names it `http.log.access` without a `log { }` block and `http.log.access.log0` with one; both verified on `caddy:2.11.7`.
    - `^(tls|http\.acme_client|pki)` is `tls`.
    - Everything else, `http.log.error` (proxy failures) and lines without a `logger` included, is `operational`.
- Panel descriptions name only events the deployed Caddy actually logs, without claiming a level for events no run has shown.
- Docs and the dashboard change in the same commit. `task lint` (including `alloy validate` on the cloud template) passes.
- Molecule containers stay unprivileged, with no systemd and no host mounts.

**Never:**

- No alert rules and no alert-backed panels (Epic 5 non-goal).
- No Caddy metrics scrape (admin `:2019`), no new exporter, no second probe besides Story 5.2's check.
- No `Cookie`/`Authorization` values in logs (Caddy redacts them by default; do not enable `log_credentials`).
- Do not change the app or its repo (`sommerfeld-io/fantasy-hockey`).
- The agent never edits Grafana Cloud through its API or UI, and never runs the vault-backed provision or deploy itself.

## I/O & Edge-Case Matrix

| Scenario            | Input / State                                      | Expected Output / Behavior                                                                  | Error Handling                                          |
|---------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------|---------------------------------------------------------|
| Normal request      | `GET https://<domain>/login` → 200                 | one `log_type="access"` line with masked IPs; Proxy status panel counts a 200               | N/A                                                     |
| App down            | app container stopped, request to the domain       | `access` line with `status` 502 (level `error`) plus `http.log.error` line as `operational` | Proxy 5xx panel shows it; the App row's 5xx stays empty |
| Certificate issued  | first start or renewal (`tls.obtain`, `tls.renew`) | lines labelled `tls`, shown in Certificate Events                                           | N/A                                                     |
| Renewal fails       | ACME error                                         | `tls` line at level `error` in Certificate Events                                           | Days-to-expiry panel keeps counting down                |
| Scanner on IP       | `http://<reserved-ip>/` → 404 from `http://` block | no access line (that block has no `log`); nothing counted                                   | N/A                                                     |
| Non-Caddy container | app container logs                                 | unchanged streams, no `log_type` label                                                      | N/A                                                     |
| Unparsable line     | Caddy prints a non-JSON line                       | kept, labelled `operational`                                                                | `json` stage failure does not drop the line             |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- `loki.source.docker "docker_containers"` forwards straight to `loki.write.grafana_cloud_loki`. Put a `loki.process` in between with a `stage.match` on `{container=~".+-caddy"}`: `stage.json` (`logger`, `level`), map `logger` to `log_type`, `stage.labels { log_type }`. Other containers pass unchanged.
- `configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml` -- asserts on the rendered `/etc/alloy/config.alloy`. Add asserts that the Caddy stage exists and that the docker source forwards to it.
- `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/templates/Caddyfile.j2` -- site block `log` becomes a `log { format filter … }` block with the IP masks, after which the logger is `http.log.access.log0`. The `http://` catch-all has no `log`, so it writes no access lines.
- `configs-cloud/digital-ocean/tests/molecule/fantasy-hockey/molecule/default/verify.yml` -- already asserts the Caddyfile's `/metrics` and catch-all blocks. Add an assert for the IP mask.
- `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json` -- v2 `RowsLayout`, rows Overview, Host, App, Containers, Logs, `panel-1` to `panel-27`, datasources `grafanacloud-prom`/`grafanacloud-logs`. `panel-17` (5xx) says Caddy's 502s are not counted, and `panel-26` (Container Logs) already shows raw Caddy lines.
- `docs/cloud/digital-ocean/monitoring.md` -- rows table, the paragraph on Caddy's 502s and the Checks list. `docs/cloud/digital-ocean/deployment.md` §Certificates says where the certificate lives; link it to the new panels.
- `docs/cloud/digital-ocean/index.md` -- an example of a `kroki-plantuml` block (mkdocs `kroki` plugin); copy its style for the new diagram.
- `docker-compose.yml` `lint-alloy-config` -- `alloy validate` (`grafana/alloy:v1.20.1`) already runs on the cloud template.

## Tasks & Acceptance

**Execution:**

- [ ] `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- add `loki.process "caddy"` between the docker source and `loki.write`, with the `log_type` mapping from Boundaries. Comment it like the other blocks -- reuses the existing collection instead of adding a second pipeline.
- [ ] `configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml` -- assert `loki.process "caddy"`, the `log_type` mapping and the docker source's `forward_to` -- the pipeline wiring has a registered test.
- [ ] `Caddyfile.j2`, fantasy-hockey Molecule verify, role `README.md` -- mask `remote_ip` and `client_ip` (IPv4 /24, IPv6 /48), assert the mask, say it in the README -- visitors are not identifiable in Grafana Cloud.
- [ ] `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json` -- add a row "Proxy" after App with these panels:
    - requests by status (`sum by (status) (count_over_time({…, container=~".+-caddy", log_type="access"} | json status [$__auto]))`)
    - Proxy 5xx
    - p95 duration (`quantile_over_time` over `unwrap duration`)
    - top 10 paths, query string stripped
    - Operational Log (`log_type="operational"`)
    - Certificate Events (`log_type="tls"`)
    - Certificate Expires In (days, from the Story 5.2 check)

  Update `panel-17`'s description to point to Proxy 5xx. Keep `panel-26` as the raw view -- one central dashboard with no duplicate panels.
- [ ] `docs/cloud/digital-ocean/monitoring.md` -- Proxy row in the rows table; a "Caddy Logs" section covering `log_type` values, which logger maps to which, the LogQL examples, and that renewal events appear only around renewals (the current certificate expires 2027-01-13, so Caddy renews from about mid-December 2026); `/metrics` as the app's monitoring endpoint (there is no `/monitoring`); that client IPs are masked; a `kroki-plantuml` component diagram showing Caddy stderr → Docker → Alloy `loki.source.docker` → `loki.process "caddy"` → Grafana Cloud Loki → Proxy row, plus the 5.2 synthetic check → Prometheus → Certificate Expires In; extended Checks -- the epic's docs-in-the-same-change rule.
- [ ] `docs/cloud/digital-ocean/deployment.md` §Certificates -- one line pointing to Certificate Events and Expires In -- an operator finds certificate status from the deploy docs.
- [ ] Local pipeline proof -- in `grafana/alloy:v1.20.1` (`docker run --rm`, unprivileged, no mounts, config written inside), feed captured Caddy lines (access 200, access 502, `http.log.error`, `tls.obtain`, non-JSON) through the same `loki.process` stages into `loki.echo`, and record the labels in Implementation Notes -- the matrix rows get evidence, because no Molecule test can run Alloy's pipeline.

**Acceptance Criteria:**

- Given the change, when `task lint`, `task cloud:molecule:test:alloy` and `task cloud:molecule:test:fantasy-hockey` run, then they pass.
- Given the operator ran `task cloud:digital-ocean:ansible:provision` and the deploy, when they query `{environment="digital-ocean", stage="prod", container="fantasy-hockey-caddy"}` in Grafana Cloud Explore, then every new line carries `log_type`, access lines carry masked IPs, the other containers' streams carry no `log_type`, and no line was duplicated.
- Given Git Sync picked up the merge on `main`, when the operator opens the dashboard with `stage=prod`, then the Proxy row shows requests, status codes, duration, top paths, the operational log, the certificate events and the days until the certificate expires, and the dashboard still has no alert rules.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

Inspection on 2026-10-15 (`9dbc461`) found:

| Item                       | State                                                                                                                 | This story             |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------|------------------------|
| Caddy access log           | on (`log` in the site block), JSON to stderr, Loki via Docker source, full client IPs                                 | mask, label, panels    |
| Caddy operational/TLS logs | always on (Caddy default logger, JSON), same path                                                                     | label and panels       |
| Log pipeline               | `discovery.docker` → `loki.source.docker` → `loki.write`, labels `container`, `instance`, `job="integrations/docker"` | add one `loki.process` |
| Certificate metrics        | none in Caddy; Story 5.2 plans an expiry check                                                                        | read the 5.2 check     |
| App `/monitoring`          | does not exist; `/metrics` scraped as `job="fantasy-hockey"`                                                          | nothing to add         |
| Alerting                   | none for the droplet (only `grafana-cloud/manifests/unsycned/alert-pihole.yml` for the homelab)                       | stays none             |
| Dashboard provisioning     | Git Sync from `main`, hand-written v2 JSON                                                                            | edit the existing file |

Logger names seen on a local `caddy:2.11.7` run (`local_certs`): `admin`, `http`, `http.auto_https`, `http.log`, `http.log.access`/`.log0`, `http.log.error`, `tls`, `tls.obtain`, `tls.cache.maintenance`, `pki.ca.local`, and lines without a logger at startup. A 502 access line has level `error`. `tls.renew` and `http.acme_client` (Let's Encrypt) show up only on the droplet, during a real ACME order or renewal. The implementer confirms them in Loki before writing panel descriptions, rather than assuming them.

Caddy metrics were rejected: the status, duration and size panels come from the access log at this traffic level, and a scrape would mean a second pipeline for the same data.

## Verification

**Commands:**

- `task lint` -- expected: all linters pass, `alloy validate` included.
- `task cloud:molecule:test:alloy` -- expected: passes with the new asserts.
- `python3 -m json.tool grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json >/dev/null` -- expected: exit 0, and a script check that every Loki and Prometheus query except the documented synthetic-monitoring one has `environment="digital-ocean"`.

**Manual checks (operator, user-run because they need the vault password):**

1. Before: Story 5.2 is done, and its check's `job` name is known.
2. After merge: run `task cloud:digital-ocean:ansible:provision` (Alloy config), then `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` (Caddyfile; short outage while the stack restarts).
3. In Explore, check the `log_type` values on the Caddy stream and that the app stream is unchanged; open the domain once and see a `status` 200 `access` line whose `client_ip` ends in `.0` (IPv4) or is cut to /48 (IPv6).
4. After Git Sync: the Proxy row shows data for `stage=prod`; the certificate stat matches `echo | openssl s_client -connect fantasy-hockey.prod.do.sommerfeld.app:443 -servername fantasy-hockey.prod.do.sommerfeld.app 2>/dev/null | openssl x509 -noout -enddate`.
5. From about mid-December 2026: after Caddy's first renewal, Certificate Events shows the renewal. Note the logger and message names seen in this spec.
