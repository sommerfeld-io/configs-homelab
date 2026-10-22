# Monitoring

The droplet and the fantasy hockey app have one Grafana Cloud dashboard: `Apps / Fantasy Hockey / Droplet` in the folder `apps-and-development`. It shows the host, the app, the Caddy proxy in front of it (with the certificate status), the containers and the logs of all containers on the droplet. The dashboard has no alert rules. The only alerts for the droplet are the three built-in rules of its [External Probe](#external-probe), and they are not routed to a contact point yet, see [Synthetic Monitoring](../../grafana-cloud/synthetic-monitoring.md#alert-routing-and-detection-time).

## Where the Dashboard Lives

The dashboard is a hand-written manifest in this repository:

| File                                                                                | Content                                           |
|-------------------------------------------------------------------------------------|---------------------------------------------------|
| `grafana-cloud/manifests/git-sync/apps-and-development/_folder.json`                | The Grafana folder `apps-and-development`         |
| `grafana-cloud/manifests/git-sync/apps-and-development/fantasy-hockey-droplet.json` | The dashboard (schema `dashboard.grafana.app/v2`) |

It reaches Grafana Cloud through Git Sync once the commit lands on `main`, the branch Git Sync reads. A dashboard change on a feature branch shows up only after the merge. Edits made later in the Grafana Cloud UI are written back to this file by Git Sync (see `grafana-cloud/manifests/git-sync/README.md`). Git Sync may rewrite IDs or the formatting of the files on its first sync, which is expected.

## Label Filter

Every query filters on `environment="digital-ocean"` and on the dashboard variable `stage` (`stage=~"$stage"`), so homelab series never show up. These labels are the `external_labels` of the droplet's Alloy config, see [Alloy and Labels](provisioning.md#alloy-and-labels). No query names the droplet or its IP.

The one exception is the stat Certificate Expires In: it reads the [External Probe](#external-probe), whose Synthetic Monitoring series carry neither `environment` nor `stage`. It filters by the check's `job="up-and-running___digital-ocean"` and `instance="https://fantasy-hockey.$stage.do.sommerfeld.app"` instead, so it still follows the `stage` variable.

| Variable    | Source                                                                    | Default |
|-------------|---------------------------------------------------------------------------|---------|
| `stage`     | `label_values(up{environment="digital-ocean"}, stage)`                    | `prod`  |
| `container` | cAdvisor label `name` of `container_cpu_usage_seconds_total` (multi, All) | All     |

A second droplet with its own stage (for example `test`) appears in the `stage` list without a dashboard change.

## Rows

| Row        | Panels                                                                                                                                                                                                                                                                                                                                                      |
|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Overview   | App up and cAdvisor up (red when down), uptime, CPU %, memory %, swap used, used share of the root disk and of the data volume (`/mnt/<droplet_name>_data`, red `No data` when it is not mounted)                                                                                                                                                           |
| Host       | CPU by mode, memory and swap, disk usage per mount point, disk I/O, network rx/tx per interface, load average                                                                                                                                                                                                                                               |
| App        | Request rate by route and by status, 5xx rate, p50/p95 latency, login events, prediction saves, process memory, goroutines                                                                                                                                                                                                                                  |
| Proxy      | From Caddy's logs (see [Caddy Logs](#caddy-logs)): requests by status, Proxy 5xx (Caddy's own 502s included), p95 duration, top 10 paths, access log lines by level and Caddy log lines by stream over time, the same two splits as donuts over the time range, Certificate Events, Operational Log; Certificate Expires In (days, from the external probe) |
| Containers | CPU, working set memory and network rx/tx per container (cAdvisor), filtered by `$container`                                                                                                                                                                                                                                                                |
| Logs       | Docker logs of the containers in `$container` (job `integrations/docker`, Caddy's raw lines included), journal logs of the droplet (job `integrations/node_exporter`)                                                                                                                                                                                       |

The app panels leave out `route="GET /metrics"`: Alloy scrapes that route every 30 seconds, which would otherwise dominate the request rate. They come from the app's own metrics, so responses Caddy answers itself (502 while the app is down or unreachable) are not counted there; Proxy 5xx in the Proxy row counts them. The Overview stats are instant queries: when Alloy stops sending, they show `No data` instead of the last value of the time range. Disk and memory headroom matter on this droplet because resizing it changes CPU and RAM only, never the disk.

All panels except Certificate Expires In use series the cloud Alloy config (`configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`) ships: node exporter, journal logs, Docker logs (Caddy's with the labels `log_type` and `stream`), cAdvisor and the app scrape at `localhost:8080/metrics` (job `fantasy-hockey`). A panel that needs a new series needs a change to that template first.

The app has no `/monitoring` endpoint. Its monitoring endpoint is `/metrics`: Alloy scrapes it on the droplet (job `fantasy-hockey`) for the App row and the App stat, and Caddy answers `/metrics` from outside with 404.

## Caddy Logs

Caddy writes all its logs as JSON lines to stderr: the access log of the app's domain and its own operational and certificate logs. They reach Loki through the existing Docker log source of Alloy; no second collector reads them, which would duplicate the streams. Between the source and `loki.write`, a `loki.process "caddy"` stage parses the JSON field `logger` of each line of the Caddy container (`container=~".+-caddy"`) and adds the label `log_type`. Lines of other containers pass unchanged and get no new label.

```kroki-plantuml
@startuml
skinparam card<<grafana>> {
  BorderColor #F46800
  BorderThickness 2
}
hide <<grafana>> stereotype
skinparam componentStyle rectangle
skinparam defaultTextAlignment center

node "Droplet" as droplet {
  component "Caddy\nJSON logs on stderr\n(client IPs masked)" as caddy
  component "Docker\njson-file log" as docker
  frame "Grafana Alloy" as alloy {
    component "discovery.relabel\n(container, stream)" as relabel
    component "loki.source.docker" as source
    component "loki.process \"caddy\"\n(log_type)" as process
    component "loki.write" as write
  }
}

card "Grafana Cloud" as grafana <<grafana>> {
  database "Loki" as loki
  database "Prometheus" as prometheus
  component "Synthetic Monitoring check\nup-and-running___digital-ocean\n(Frankfurt, Paris)" as check
  frame "Dashboard Apps / Fantasy Hockey / Droplet" as dashboard {
    component "Proxy row\nrequests, 5xx, duration, paths,\nlog volume, Operational Log,\nCertificate Events" as proxyrow
    component "Certificate Expires In" as expiry
  }
}

caddy --> docker : stderr
docker --> source : container logs
relabel ..> source : relabel_rules
source --> process
process --> write
write --> loki : environment, stage
loki --> proxyrow : LogQL
check --> caddy : HTTPS :443
check --> prometheus : probe_ssl_earliest_cert_expiry
prometheus --> expiry : PromQL
@enduml
```

### Log Types

The label `log_type` is matched by prefix of the Caddy logger name:

| `log_type`    | Logger (prefix)                             | Content                                                                                                                                                                      |
|---------------|---------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `access`      | `http.log.access`                           | One line per request on the app's domain; with the `log { }` block of the Caddyfile the logger is `http.log.access.log0`                                                     |
| `tls`         | `tls`, `http.acme_client`, `pki`            | Certificates: `tls.obtain` when Caddy obtains one, `tls.cache.maintenance` and storage cleaning in between; renewal and ACME order lines only during a real renewal or order |
| `operational` | everything else, lines without `logger` too | Startup and config lines, proxy errors (`http.log.error`, for example while the app is down), lines that are not JSON                                                        |

`log_type` and `stream` are the only new labels. Everything else (`request.uri`, `status`, `request.client_ip`, `duration`, `level`, `logger`) stays in the line and is parsed at query time with `| json`, which keeps the number of Loki streams low.

The label `stream` (`stdout` or `stderr`) is Docker's output stream, copied from `__meta_docker_container_log_stream` by a relabel rule for the Caddy container only. Caddy writes all its logs to stderr, so the `stdout` series of Caddy Log Lines by Stream and of the Caddy Output Streams donut is expected to stay at or near zero.

Caddy masks client IPs before it writes a line: `remote_ip` and `client_ip` are cut to /24 for IPv4 (`203.0.113.0`) and /48 for IPv6, both in the access log and in Caddy's own logs (a global `log` block with the same filter covers `http.log.error`). The same filters delete the client-sent headers `X-Forwarded-For`, `X-Real-Ip` and `Forwarded` from the logged request, because they can carry the full IP. Visitors are not identifiable in Grafana Cloud. `Cookie` and `Authorization` values are redacted, Caddy's default. Requests to the reserved IP on `http://` get a 404 from a block without `log` and write no access line.

### LogQL Examples

All examples keep the dashboard's label filter; in Explore, replace `$stage` with `prod`, `$__auto` with a window such as `5m` and `$__range` with the time range such as `24h`.

Requests by status:

```logql
sum by (status) (count_over_time({environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="access"} | json status [$__auto]))
```

5xx as Caddy sees them (its own 502s included):

```logql
sum by (status) (count_over_time({environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="access"} | json status | status=~"5.." [$__auto]))
```

p95 duration in seconds:

```logql
quantile_over_time(0.95, {environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="access"} | json duration | __error__="" | unwrap duration | __error__="" [$__auto]) by (stage)
```

Top 10 paths, query string stripped:

```logql
topk(10, sum by (path) (count_over_time({environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="access"} | json uri="request.uri" | label_format path=`{{ regexReplaceAll "[?].*" .uri "" }}` [$__range])))
```

Certificate events and the operational log:

```logql
{environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="tls"}
{environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="operational"}
```

### Log Volume

Four panels show how many lines Caddy writes. Access Log Lines by Level (time series) and Access Log Levels (donut over the time range) split the access log by its `level` field; a response with status 5xx is logged at level `error`. Caddy Log Lines by Stream (time series) and Caddy Output Streams (donut) split all Caddy lines by the `stream` label.

```logql
sum by (level) (count_over_time({environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", log_type="access"} | json level [$__auto]))
sum by (stream) (count_over_time({environment="digital-ocean", stage=~"$stage", job="integrations/docker", container=~".+-caddy", stream=~".+"} [$__auto]))
```

The donuts run the same queries as instant queries over `[$__range]`. `stream=~".+"` leaves out Caddy lines from before the `stream` label existed, which would otherwise show as an unnamed series.

### Certificate Status

Caddy exports no certificate metric. The stat Certificate Expires In reads the [External Probe](#external-probe) instead, the lowest value of its probes, in days:

```promql
min(probe_ssl_earliest_cert_expiry{job="up-and-running___digital-ocean", instance="https://fantasy-hockey.$stage.do.sommerfeld.app"} - time()) / 86400
```

It turns orange below 30 days (Caddy renews when about 30 days are left) and red below 14 days, the threshold of the check's alert. Certificate Events shows what Caddy did. Renewal lines appear only around a renewal: the current certificate expires on 2027-01-13, so Caddy renews it from about mid-December 2026. A renewal that keeps failing shows up as `tls` lines in Certificate Events while the days in Certificate Expires In keep counting down.

## External Probe

A Grafana Cloud Synthetic Monitoring check requests `https://fantasy-hockey.prod.do.sommerfeld.app` every 10 minutes from the public probes in Frankfurt and Paris, under the job `up-and-running___digital-ocean`, so an outage anywhere on the path to the droplet (DNS, reserved IP, Caddy, the app) becomes visible from outside. The check fails when the certificate is invalid, and its alert fires when the certificate expires within 14 days. It is declared with OpenTofu next to the website checks, see [Synthetic Monitoring](../../grafana-cloud/synthetic-monitoring.md).

## Checks

After the commit is on `main` and Git Sync picked it up, open `Apps / Fantasy Hockey / Droplet` with `stage=prod`:

- The App and cAdvisor stats show `Up`, and Volume Disk shows a percentage, not `No data`.
- CPU, memory, disks, the app panels, the container panels and the container logs show data.
- The Proxy row shows requests by status, duration, top paths, the operational log, the log volume panels and Certificate Expires In in days; Certificate Events shows lines once Caddy has logged certificate activity in the time range.
- Certificate Expires In matches the certificate's end date: `echo | openssl s_client -connect fantasy-hockey.prod.do.sommerfeld.app:443 -servername fantasy-hockey.prod.do.sommerfeld.app 2>/dev/null | openssl x509 -noout -enddate`.
- In Explore, `{environment="digital-ocean", stage="prod", container="fantasy-hockey-caddy"}` shows `log_type` and `stream` on every new line, an access line's `client_ip` ends in `.0` (IPv4) or is cut to /48 (IPv6), and the app container's lines carry neither label.
- No Caddy line is duplicated: over the same short window (for example the last 5 minutes), the line count of `{environment="digital-ocean", stage="prod", container="fantasy-hockey-caddy"}` in Explore matches `ssh root@<reserved-ip> 'docker logs --since 5m fantasy-hockey-caddy 2>&1 | wc -l'`.
- An IPv6 client IP is cut to /48: after opening the domain over IPv6 (`curl -6 https://fantasy-hockey.prod.do.sommerfeld.app/login` from an IPv6 network), the access line's `client_ip` keeps only the first three groups, followed by `::`.
- The dashboard has no alert rules.
- In Grafana Cloud under Alerts & IRM > Alerting, the check `fantasy-hockey.prod.do.sommerfeld.app` has its three alert rules, `TLSTargetCertificateCloseToExpiring` with 14 days and `HTTPRequestDurationTooHighAvg` with 300 ms (`tofu state show 'grafana_synthetic_monitoring_check_alerts.this["fantasy-hockey.prod.do.sommerfeld.app"]'` in `grafana-cloud/opentofu` shows the same).
