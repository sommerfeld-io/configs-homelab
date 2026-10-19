---
title: 'Story 5.3: Caddy logs and certificate status on the droplet dashboard'
type: 'feature'
created: '2026-10-15'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '50a823f6ac3dadf5c25eef41fb2ad112920b359f'
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

**Decisions (human, 2026-10-16):**

- **Log volume panels:** the Proxy row also shows how many Caddy log lines are written over time: time series "Access Log Lines by Level" (`log_type="access"`, `sum by (level)` from `| json level`) and "Caddy Log Lines by Stream" (all Caddy lines, `sum by (stream)`), plus two donut panels (pie chart, `pieType` `donut`) over the dashboard time range for the same splits: "Access Log Levels" and "Caddy Output Streams".
- **`stream` label:** Docker's output stream is not in the line, so the docker source's relabel rules copy `__meta_docker_container_log_stream` to a `stream` label (`stdout`/`stderr`) for containers matching `.+-caddy` only. Caddy writes all its logs to stderr by default, so the stdout series is expected to stay at or near zero; the panel descriptions say so.

## Boundaries & Constraints

**Always:**

- Reuse the existing Docker log source in `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`, with a processing stage between it and `loki.write`. Never add a second source for the same container: duplicate streams.
- Put new labels only into the cloud template, never into the fleet `config.alloy.j2`.
- `log_type` and `stream` (Caddy container only) are the only new stream labels. `uri`, `status`, `client_ip`, `duration`, `level` and `logger` stay in the line, parsed at query time with `| json`.
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
| Non-Caddy container | app container logs                                 | unchanged streams, no `log_type` or `stream` label                                          | N/A                                                     |
| Caddy output stream | any Caddy line (Caddy logs to stderr)              | line carries `stream="stderr"`; Caddy Output Streams donut shows stderr                     | a line on stdout gets `stream="stdout"`                 |
| Unparsable line     | Caddy prints a non-JSON line                       | kept, labelled `operational`                                                                | `json` stage failure does not drop the line             |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- `loki.source.docker "docker_containers"` forwards straight to `loki.write.grafana_cloud_loki`. Put a `loki.process` in between with a `stage.match` on `{container=~".+-caddy"}`: `stage.json` (`logger`, `level`), map `logger` to `log_type`, `stage.labels { log_type }`. Other containers pass unchanged.
- `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- `discovery.relabel "docker_containers"` supplies the docker source's `relabel_rules`. Add a rule with `source_labels = ["__meta_docker_container_name", "__meta_docker_container_log_stream"]`, `regex = "/.+-caddy;(.*)"`, `target_label = "stream"`, so only the Caddy container gets `stream`.
- `configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml` -- asserts on the rendered `/etc/alloy/config.alloy`. Add asserts that the Caddy stage exists, that the docker source forwards to it, and that the `stream` rule is present.
- `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/templates/Caddyfile.j2` -- site block `log` becomes a `log { format filter … }` block with the IP masks, after which the logger is `http.log.access.log0`. The `http://` catch-all has no `log`, so it writes no access lines.
- `configs-cloud/digital-ocean/tests/molecule/fantasy-hockey/molecule/default/verify.yml` -- already asserts the Caddyfile's `/metrics` and catch-all blocks. Add an assert for the IP mask.
- `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json` -- v2 `RowsLayout`, rows Overview, Host, App, Containers, Logs, `panel-1` to `panel-27`, datasources `grafanacloud-prom`/`grafanacloud-logs`. `panel-17` (5xx) says Caddy's 502s are not counted, and `panel-26` (Container Logs) already shows raw Caddy lines.
- `docs/cloud/digital-ocean/monitoring.md` -- rows table, the paragraph on Caddy's 502s and the Checks list. `docs/cloud/digital-ocean/deployment.md` §Certificates says where the certificate lives; link it to the new panels.
- `docs/cloud/digital-ocean/index.md` -- an example of a `kroki-plantuml` block (mkdocs `kroki` plugin); copy its style for the new diagram.
- `docker-compose.yml` `lint-alloy-config` -- `alloy validate` (`grafana/alloy:v1.20.1`) already runs on the cloud template.

## Tasks & Acceptance

**Execution:**

- [x] `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- add `loki.process "caddy"` between the docker source and `loki.write`, with the `log_type` mapping from Boundaries. Comment it like the other blocks -- reuses the existing collection instead of adding a second pipeline.
- [x] `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- add the Caddy-only `stream` relabel rule from the Code Map -- the stdout/stderr panels have a label to group by.
- [x] `configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml` -- assert `loki.process "caddy"`, the `log_type` mapping, the docker source's `forward_to` and the `stream` rule -- the pipeline wiring has a registered test.
- [x] `Caddyfile.j2`, fantasy-hockey Molecule verify, role `README.md` -- mask `remote_ip` and `client_ip` (IPv4 /24, IPv6 /48), assert the mask, say it in the README -- visitors are not identifiable in Grafana Cloud.
- [x] `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json` -- add a row "Proxy" after App with these panels:
    - requests by status (`sum by (status) (count_over_time({…, container=~".+-caddy", log_type="access"} | json status [$__auto]))`)
    - Proxy 5xx
    - p95 duration (`quantile_over_time` over `unwrap duration`)
    - top 10 paths, query string stripped
    - Operational Log (`log_type="operational"`)
    - Certificate Events (`log_type="tls"`)
    - Certificate Expires In (days, from the Story 5.2 check)
    - Access Log Lines by Level (time series, `sum by (level) (count_over_time({…, container=~".+-caddy", log_type="access"} | json level [$__auto]))`)
    - Caddy Log Lines by Stream (time series, `sum by (stream) (count_over_time({…, container=~".+-caddy"} [$__auto]))`)
    - Access Log Levels and Caddy Output Streams (pie charts with `pieType` `donut`, same selectors, instant queries over `[$__range]`)

  Update `panel-17`'s description to point to Proxy 5xx. Keep `panel-26` as the raw view -- one central dashboard with no duplicate panels.
- [x] `docs/cloud/digital-ocean/monitoring.md` -- Proxy row in the rows table; a "Caddy Logs" section covering `log_type` values, which logger maps to which, the LogQL examples, and that renewal events appear only around renewals (the current certificate expires 2027-01-13, so Caddy renews from about mid-December 2026); `/metrics` as the app's monitoring endpoint (there is no `/monitoring`); that client IPs are masked; the Caddy-only `stream` label and that Caddy logs to stderr; the log volume panels and their LogQL; a `kroki-plantuml` component diagram showing Caddy stderr → Docker → Alloy `loki.source.docker` → `loki.process "caddy"` → Grafana Cloud Loki → Proxy row, plus the 5.2 synthetic check → Prometheus → Certificate Expires In; extended Checks -- the epic's docs-in-the-same-change rule.
- [x] `docs/cloud/digital-ocean/deployment.md` §Certificates -- one line pointing to Certificate Events and Expires In -- an operator finds certificate status from the deploy docs.
- [x] Local pipeline proof -- in `grafana/alloy:v1.20.1` (`docker run --rm`, unprivileged, no mounts, config written inside), feed captured Caddy lines (access 200, access 502, `http.log.error`, `tls.obtain`, non-JSON) through the same `loki.process` stages into `loki.echo`, and record the labels in Implementation Notes -- the matrix rows get evidence, because no Molecule test can run Alloy's pipeline.

**Acceptance Criteria:**

- Given the change, when `task lint`, `task cloud:molecule:test:alloy` and `task cloud:molecule:test:fantasy-hockey` run, then they pass.
- Given the operator ran `task cloud:digital-ocean:ansible:provision` and the deploy, when they query `{environment="digital-ocean", stage="prod", container="fantasy-hockey-caddy"}` in Grafana Cloud Explore, then every new line carries `log_type`, access lines carry masked IPs, the other containers' streams carry no `log_type`, and no line was duplicated.
- Given Git Sync picked up the merge on `main`, when the operator opens the dashboard with `stage=prod`, then the Proxy row shows requests, status codes, duration, top paths, the operational log, the certificate events, the days until the certificate expires, access log lines by level and Caddy log lines by stream over time, and the level and stream donuts, and the dashboard still has no alert rules.

## Implementation Notes

- Alloy (`config.alloy.j2`): `loki.source.docker` now forwards to `loki.process "caddy"`, which forwards to `loki.write`. Inside one `stage.match` on `{container=~".+-caddy"}`: `stage.json` extracts `logger` only (`level` stays in the line and is not needed for the mapping), `stage.labels` promotes it to a temporary label, `stage.static_labels` sets `log_type="operational"`, two nested `stage.match` blocks on `{logger=~"http\\.log\\.access.*"}` and `{logger=~"(tls|http\\.acme_client|pki).*"}` override it with `access` and `tls`, and `stage.label_drop` removes `logger`. This avoids a Go template inside the Jinja template. The Caddy-only `stream` rule is in `discovery.relabel "docker_containers"` as specified.
- Caddyfile: the site's `log` became `log { format filter { request>remote_ip ip_mask 24 48; request>client_ip ip_mask 24 48 } }`. The local run showed that the proxy error line (`http.log.error.log0`) carries the request with the **unmasked** client IP, because the site filter covers only the access log. A global options block `{ log { format filter { … same masks … } } }` now masks the default logger as well; with it, every line of the run had masked IPs. `caddy validate` and `caddy fmt --diff` are clean on the rendered file (`caddy:2.11.7`).
- Captured on `caddy:2.11.7` (`local_certs`, stand-in app via `caddy respond`, config written inside the container, no mounts): access 200 over IPv4 (`remote_ip` `127.0.0.0`) and IPv6 (`::1` → `::`), `Cookie` value `REDACTED`, 404 on `http://127.0.0.1/` with no access line, access 502 at level `error` plus `http.log.error.log0` "connection refused" at level `error`, `tls.obtain`, `tls.cache.maintenance`, `tls` storage cleaning, `pki.ca.local`, startup lines without a logger. All lines went to stderr.
- Pipeline proof (`grafana/alloy:v1.20.1`, `docker run --rm`, unprivileged, no mounts, config written inside): the template's `discovery.relabel "docker_containers"` rules and `loki.process "caddy"` block, extracted verbatim, with `loki.source.file` targets carrying `__meta_docker_container_name`/`__meta_docker_container_log_stream` in place of the Docker source, into `loki.echo`. 13 lines in, 13 out, no `logger` label left:

    | Input line                                       | Labels added                                |
    |--------------------------------------------------|---------------------------------------------|
    | access 200 (`http.log.access.log0`)              | `log_type="access"`, `stream="stderr"`      |
    | access 502 (`http.log.access.log0`, level error) | `log_type="access"`, `stream="stderr"`      |
    | access without `log0` (`http.log.access`)        | `log_type="access"`, `stream="stderr"`      |
    | `http.log.error.log0`                            | `log_type="operational"`, `stream="stderr"` |
    | `tls.obtain`, `tls.cache.maintenance`, `tls`     | `log_type="tls"`, `stream="stderr"`         |
    | `pki.ca.local`                                   | `log_type="tls"`, `stream="stderr"`         |
    | `http.acme_client` (synthetic line)              | `log_type="tls"`, `stream="stderr"`         |
    | `http.log` "server running", no logger (startup) | `log_type="operational"`, `stream="stderr"` |
    | non-JSON line (synthetic)                        | `log_type="operational"`, `stream="stderr"` |
    | Caddy line on stdout (synthetic)                 | `log_type="operational"`, `stream="stdout"` |
    | app container line                               | none (no `log_type`, no `stream`)           |

- LogQL proof: the echoed streams were pushed into a throwaway `grafana/loki:3.5.5` (no mounts; run as `--user 0` because the image's own user could not exec in this devcontainer), and every Loki query of panels 28 to 38 ran with `$stage`=`prod`: status 200×2/502×1, Proxy 5xx 502×1, p95 duration, top paths `/login`×2 and `/` (query string stripped), level error×1/info×2, stream stderr×11/stdout×1, both log panels returned their streams.
- Dashboard: row Proxy inserted after App; new elements `panel-28` to `panel-38` appended rather than renumbering 23 to 27, so `panel-26` stays Container Logs. Certificate Expires In reads `min(probe_ssl_earliest_cert_expiry{job="up-and-running___digital-ocean", instance="https://fantasy-hockey.$stage.do.sommerfeld.app"} - time()) / 86400` (instance follows `$stage`), unit `days`, orange below 30, red below 14, null mapped to red No data. Script check: 48 queries, all with `environment="digital-ocean"` and `stage=~"$stage"` except `panel-34`. The dashboard description and `panel-17` were updated.
- `task lint` (with `alloy validate` on the cloud template), `task cloud:molecule:test:alloy` and `task cloud:molecule:test:fantasy-hockey` pass. The fantasy-hockey verify asserts two `format filter` blocks with both masks, the global `log` block, and no `log_credentials` directive line.
- Not verified here (no Loki access): the logger names `tls.renew` and `http.acme_client` on the droplet, and the `job`/`instance` labels of the synthetic check's series; panel descriptions name only events seen in the local run. Operator manual checks 3 to 5 remain.

## Spec Change Log

- 2026-10-16, human renegotiation at build start: added the log volume panels (access lines by level, Caddy lines by stream, two donuts) and the Caddy-only `stream` label; widened the `log_type`-only label rule, the non-Caddy matrix row, a new matrix row, the Code Map, Tasks and the dashboard AC accordingly.

## Review Triage Log

Review 1 (2026-10-16): blind-hunter, edge-case-hunter, verification-gap.

| #  | Layer  | Finding                                                               | Verdict     | Route  | Evidence                                                                                                                       |
|----|--------|-----------------------------------------------------------------------|-------------|--------|--------------------------------------------------------------------------------------------------------------------------------|
| 1  | VG     | No automated `caddy validate` on the rendered Caddyfile               | medium      | defer  | Pre-existing since 7.2: no Caddyfile linter anywhere; Molecule only text-matches. Deferred-work entry                            |
| 2  | VG     | `log_type` mapping has no repeatable behavioral test                  | medium      | defer  | Only the manual `loki.echo` proof; needs a new Docker harness. Deferred-work entry                                               |
| 3  | BH     | Spec `in-review` vs sprint `in-progress` mismatch                     | false       | reject | Build syncs sprint status at its own steps; the spec status is transient during review                                          |
| 4  | BH     | X-Forwarded-For/X-Real-Ip/Forwarded headers leak full client IPs      | medium      | patch  | Access log records `request.headers`; fixed with `delete` filters in both blocks, Molecule assert, README and docs              |
| 5  | BH     | Query strings in `request.uri` may carry tokens or e-mail addresses   | maybe-false | defer  | Depends on whether the app uses secrets in GET query strings; unverified medium. Deferred-work entry                            |
| 6  | BH     | Top Paths may exceed Loki's series limit over long ranges             | maybe-false | defer  | Depends on scanner path variety in production; unverified medium. Deferred-work entry                                           |
| 7  | BH     | Hard-coded certificate date goes stale                                | low         | patch  | panel-33 description now states the renewal rule; the dated sentence stays in monitoring.md as the spec requires                |
| 8  | BH     | Proxy panels count per interval while panel-17 is a rate              | false       | reject | Descriptions of panel-28/29 say "per interval"; no misleading comparison of values                                              |
| 9  | BH, EC | `__error__` filter before `unwrap` only: conversion error fails query | low         | patch  | Added `| __error__=""` after `unwrap duration` in panel-30 and monitoring.md                                                     |
| 10 | BH, EC | Pre-deploy Caddy lines without `stream` show as an unnamed series     | low         | patch  | Added `stream=~".+"` to panel-36/38 and the docs query                                                                          |
| 11 | BH, EC | Alloy verify `regex_search` returns None on no match                  | false       | reject | The task still fails loudly on a missing block; the error message is less pretty but the test does not pass                     |
| 12 | BH     | No negative test that the fleet template stays free of Caddy stages   | low         | reject | Unlikely in everyday use; fix adds a new assert against another scenario                                                        |
| 13 | BH     | `decimals: 0` shows 29.6 as "30" in orange                            | low         | patch  | panel-34 `decimals` set to 1                                                                                                     |
| 14 | BH     | Checks miss duplicate-line and IPv6 checks; deploy outage not in docs | low         | patch  | Two Checks items in monitoring.md, one sentence in deployment.md                                                                |
| 15 | EC     | `[$__range]` instant queries fail beyond Loki's max query length      | low         | reject | Only for ranges above about 30 days; fix needs per-panel time caps                                                              |
| 16 | EC     | panel-34 uses `$stage` in an equality matcher; custom regex breaks it | low         | reject | `stage` holds a single value from `label_values`; a custom regex value is unlikely, fix adds escaping                           |
| 17 | EC     | `stream` from `loki.source.docker` not proven, file source stood in   | false       | reject | `loki.source.docker` exposes `__meta_docker_container_log_stream` to `relabel_rules` per its documentation; manual check 3 confirms |

Verification after patches: `task lint` exit 0, `task cloud:molecule:test:alloy` exit 0, `task cloud:molecule:test:fantasy-hockey` passed (implementer), JSON script check: only `panel-34` lacks the environment/stage filter (documented exception).

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
