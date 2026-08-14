# Security Monitoring – Raspberry Pi Nodes

This page describes the security monitoring setup deployed across all five Raspberry Pi nodes (`pi4-01` through `pi5-01`). The stack is designed to detect intrusions in real time, audit system hardening nightly, and surface all findings in Grafana Cloud — with zero custom middleware between the data sources and Alloy.

---

## Overview

Two complementary tools form the security layer:

- **[CrowdSec](https://www.crowdsec.net/)** – a real-time behavioural intrusion-detection system that analyses logs, detects threats (SSH brute-force, port scans, HTTP attacks), and applies iptables/nftables bans via a local firewall bouncer.
- **[Lynis](https://cisofy.com/lynis/)** – a nightly system-hardening audit that produces a hardening index (0–100) and a detailed report. It runs as an ephemeral Docker container triggered by cron.

Both data sources feed into the existing [Grafana Alloy](../../ansible/roles/grafana-cloud/alloy.md) telemetry pipeline without any custom HTTP servers or middleware. Alloy scrapes CrowdSec's built-in Prometheus endpoint directly and reads Lynis metrics from a textfile written by the cron job.

---

## Architecture

### Component Overview

```plantuml
@startuml security-overview
!theme plain

skinparam componentStyle rectangle
skinparam backgroundColor #1e1e2e
skinparam defaultFontColor #cdd6f4
skinparam componentBorderColor #89b4fa
skinparam componentBackgroundColor #313244
skinparam arrowColor #89b4fa
skinparam noteBorderColor #a6e3a1
skinparam noteBackgroundColor #1e1e2e
skinparam noteFontColor #a6e3a1

title Security Monitoring – Component Overview (per Raspberry Pi node)

package "Raspberry Pi Node" {

  package "Docker (managed by Ansible)" {
    [CrowdSec LAPI\n:6060/metrics] as crowdsec
    [Firewall Bouncer] as bouncer
  }

  package "Cron (nightly 02:00)" {
    [Lynis Container\n(ephemeral)] as lynis
  }

  database "/var/lib/node_exporter/\ntextfile_collector/lynis.prom" as textfile
  database "/var/log/lynis/lynis-run.log" as lynis_log
  database "/var/log/auth.log\n/var/log/syslog\n/var/log/kern.log" as host_logs

  component "Grafana Alloy\n(native service)" as alloy {
    [prometheus.exporter.unix\n(+textfile collector)] as unix_exp
    [prometheus.scrape\ncrowdsec :6060] as scrape_cs
    [loki.source.docker\n(CrowdSec container)] as docker_src
    [loki.source.file\n(lynis-run.log)] as file_src
    [prometheus.remote_write] as prom_write
    [loki.write] as loki_write
  }
}

cloud "Grafana Cloud" {
  [Prometheus\n(Mimir)] as mimir
  [Loki] as loki
  [Grafana Dashboards] as dashboards
}

crowdsec --> host_logs : reads (ro bind-mount)
crowdsec ..> bouncer : LAPI decisions
lynis --> textfile : writes lynis.prom
lynis --> lynis_log : appends stdout/stderr

unix_exp --> textfile : reads *.prom
scrape_cs --> crowdsec : GET /metrics
docker_src --> crowdsec : container stdout/stderr
file_src --> lynis_log : tail

unix_exp --> prom_write
scrape_cs --> prom_write
docker_src --> loki_write
file_src --> loki_write

prom_write --> mimir
loki_write --> loki
mimir --> dashboards
loki --> dashboards

@enduml
```

### Key design decisions

- **No custom HTTP servers or middleware.** CrowdSec exposes a built-in Prometheus endpoint at `:6060/metrics`; Alloy scrapes it directly. Lynis writes a `.prom` textfile that Alloy's `prometheus.exporter.unix` textfile collector reads on every scrape cycle. No Pushgateway, no Python scripts.
- **Alloy is error-tolerant.** When a scrape target is unreachable (e.g., CrowdSec not yet deployed), Alloy records `up=0` and forwards nothing else to Grafana Cloud. No error is raised. The same applies to `loki.source.file` — if the Lynis log file does not yet exist, Alloy waits silently.
- **Ephemeral container logs are captured via file-tail.** The Lynis container exits before `loki.source.docker` can discover it. The cron job redirects all output to `/var/log/lynis/lynis-run.log`, which Alloy tails with `loki.source.file`.

---

## Data Flow – Metrics

### CrowdSec Metrics Pipeline

```plantuml
@startuml crowdsec-metrics-flow
!theme plain

skinparam backgroundColor #1e1e2e
skinparam defaultFontColor #cdd6f4
skinparam activityBorderColor #89b4fa
skinparam activityBackgroundColor #313244
skinparam arrowColor #89b4fa
skinparam partitionBorderColor #6c7086
skinparam partitionBackgroundColor #181825

title CrowdSec Metrics – Data Flow

|Raspberry Pi Node|
start
:CrowdSec analyses host log files;
:CrowdSec exposes Prometheus metrics\nat localhost:6060/metrics;

|Alloy|
:discovery.relabel "integrations_crowdsec"\nsets instance=hostname, job="integrations/crowdsec";
:prometheus.scrape "integrations_crowdsec"\n(every 30 s, timeout 10 s);
if (target reachable?) then (yes)
  :prometheus.relabel "integrations_crowdsec"\nkeeps: cs_active_decisions, cs_alerts,\ncs_buckets, cs_lapi_decisions, up;
  :prometheus.remote_write "metrics_service";
  |Grafana Cloud|
  :Prometheus (Mimir) stores metrics;
  :Security dashboards query metrics;
else (no – CrowdSec not running)
  :up=0 only is forwarded;
  note right: No Alloy errors.\nDashboard shows "CrowdSec DOWN" (red).
endif
stop

@enduml
```

### Lynis Hardening Index Pipeline

```plantuml
@startuml lynis-metrics-flow
!theme plain

skinparam backgroundColor #1e1e2e
skinparam defaultFontColor #cdd6f4
skinparam activityBorderColor #89b4fa
skinparam activityBackgroundColor #313244
skinparam arrowColor #89b4fa
skinparam partitionBorderColor #6c7086
skinparam partitionBackgroundColor #181825

title Lynis Hardening Index – Data Flow

|Cron (02:00 daily)|
start
:docker run --rm debian:bookworm-slim;
:apt-get install lynis;
:lynis audit system --cronjob;
:Parse hardening_index from lynis-report.dat;
:Write lynis_hardening_index{instance,job} to\n/var/lib/node_exporter/textfile_collector/lynis.prom;
:Append stdout/stderr to /var/log/lynis/lynis-run.log;
:Container exits (ephemeral --rm);

|Alloy|
:prometheus.exporter.unix textfile collector\nreads /textfile_collector/*.prom on next scrape;
if (lynis.prom exists?) then (yes)
  :lynis_hardening_index metric is available;
  :Flows through existing node_exporter\nscrape → relabel → remote_write chain;
  |Grafana Cloud|
  :Prometheus stores lynis_hardening_index;
  :Hardening Index panel turns green/orange/red;
else (no – first run not yet complete)
  :No metric emitted for this gauge;
  note right: No Alloy errors.\nDashboard shows "Not yet run" (red)\nuntil first cron execution.
endif
stop

@enduml
```

---

## Data Flow – Logs

### CrowdSec Container Logs

CrowdSec runs as a long-lived Docker container. Alloy's `loki.source.docker` discovers it automatically and forwards its stdout/stderr to Grafana Cloud Loki with the labels `job="integrations/docker"` and `container="crowdsec"`.

```plantuml
@startuml crowdsec-logs-flow
!theme plain

skinparam backgroundColor #1e1e2e
skinparam defaultFontColor #cdd6f4
skinparam activityBorderColor #89b4fa
skinparam activityBackgroundColor #313244
skinparam arrowColor #89b4fa
skinparam partitionBorderColor #6c7086
skinparam partitionBackgroundColor #181825

title CrowdSec – Log Data Flow

|Docker|
start
:CrowdSec container running (long-lived);
:Writes ban/alert events to stdout;

|Alloy|
:loki.source.docker discovers container\nvia /var/run/docker.sock;
:discovery.relabel sets\njob="integrations/docker"\ncontainer="crowdsec"\ninstance=hostname;
:loki.write forwards to Grafana Cloud Loki;

|Grafana Cloud|
:Loki stores log stream\n{job="integrations/docker", container="crowdsec"};
:Security dashboard Logs panel queries\n{job="integrations/docker", container="crowdsec"};
stop

@enduml
```

### Lynis Audit Logs

The Lynis container is ephemeral (exits after the audit). Alloy cannot use `loki.source.docker` for it. Instead, the cron job appends all output to a persistent host-side log file that Alloy tails with `loki.source.file`.

```plantuml
@startuml lynis-logs-flow
!theme plain

skinparam backgroundColor #1e1e2e
skinparam defaultFontColor #cdd6f4
skinparam activityBorderColor #89b4fa
skinparam activityBackgroundColor #313244
skinparam arrowColor #89b4fa
skinparam partitionBorderColor #6c7086
skinparam partitionBackgroundColor #181825

title Lynis – Audit Log Data Flow

|Cron|
start
:docker run --rm ... >> /var/log/lynis/lynis-run.log 2>&1;
:Audit output appended to host file;
:Container exits;

|Alloy|
:loki.source.file tails /var/log/lynis/lynis-run.log;
note right: File is created on first run.\nAlloy waits silently until the file exists.
:loki.write forwards new lines to Grafana Cloud Loki;

|Grafana Cloud|
:Loki stores log stream\n{job="integrations/security", instance=hostname};
:Security dashboard Logs panel queries\n{job="integrations/security"};
stop

@enduml
```

---

## Grafana Dashboards

Two dashboards are provisioned under the **Security** folder in Grafana Cloud via git-sync:

| Dashboard | UID | Purpose |
|---|---|---|
| `security-summary.json` | `security-raspi-summary` | Fleet-wide view across all 5 Pi nodes |
| `security-details.json` | `security-raspi-details` | Per-node deep-dive (node selected via template variable) |

### Data Freshness Row

Both dashboards open with a mandatory **Data Freshness** row. These stat panels show when metrics and logs were last successfully received, so a silent failure (exporter down, cron not running) is immediately visible:

| Panel | Datasource | Query | Green | Yellow | Red |
|---|---|---|---|---|---|
| Metrics Last Received – CrowdSec | Prometheus | `time() - timestamp(up{job="integrations/crowdsec",...})` | < 120 s | < 300 s | ≥ 300 s |
| Metrics Last Received – Node Exporter | Prometheus | `time() - timestamp(up{job="integrations/node_exporter",...})` | < 180 s | < 600 s | ≥ 600 s |
| Metrics Last Received – Lynis Index | Prometheus | `time() - timestamp(lynis_hardening_index{...})` | < 86 400 s | < 172 800 s | ≥ 172 800 s |
| Logs Last Received – Lynis Audit | Loki | `count_over_time({job="integrations/security"}[25h])` | > 0 | – | = 0 |
| Logs Last Received – CrowdSec | Loki | `count_over_time({job="integrations/docker",container="crowdsec"}[15m])` | > 0 | – | = 0 |

### Dashboard Structure

```plantuml
@startuml dashboard-structure
!theme plain

skinparam backgroundColor #1e1e2e
skinparam defaultFontColor #cdd6f4
skinparam rectangleBorderColor #89b4fa
skinparam rectangleBackgroundColor #313244
skinparam arrowColor #89b4fa
skinparam titleFontColor #cdd6f4
skinparam legendBorderColor #6c7086

title Grafana Dashboard Structure – Security

rectangle "Security (Grafana Folder)" {

  rectangle "security-summary.json\n(all 5 nodes)" {
    rectangle "Row: Data Freshness" as sf1 #45475a
    rectangle "Row: Fleet Status\n(CrowdSec up/down per node,\nhardening index bar gauge,\ntotal blocked IPs)" as sf2 #45475a
    rectangle "Row: Threat Overview\n(SSH brute-force, port scan,\nHTTP attacks – status history)" as sf3 #45475a
    rectangle "Row: Recent Events\n(ban decisions log table,\noutdated packages bar chart)" as sf4 #45475a
    sf1 -[hidden]-> sf2
    sf2 -[hidden]-> sf3
    sf3 -[hidden]-> sf4
  }

  rectangle "security-details.json\n(single node – $node variable)" {
    rectangle "Row: Data Freshness" as df1 #45475a
    rectangle "Row: Node Status\n(CrowdSec up, hardening index,\nblocked IPs, alerts, packages)" as df2 #45475a
    rectangle "Row: Threat Detail\n(per-threat status history,\ndecisions time series)" as df3 #45475a
    rectangle "Row: Logs\n(Lynis audit log, CrowdSec events)" as df4 #45475a
    df1 -[hidden]-> df2
    df2 -[hidden]-> df3
    df3 -[hidden]-> df4
  }
}

@enduml
```

---

## Ansible Deployment

The security stack is deployed by the dedicated playbook `ansible/playbooks/deploy-security-stack.yml`, which targets the `raspi` inventory group. It uses the `security/crowdsec-lynis` Ansible role to:

1. Create `/opt/security-stack/` on each node.
2. Copy the Docker Compose file and CrowdSec acquisition config.
3. Template the `.env` file (with vault-encrypted secrets) at `mode: 0600`.
4. Ensure `/var/log/lynis/` and `/var/lib/node_exporter/textfile_collector/` exist.
5. Start the stack with `community.docker.docker_compose_v2`.
6. Schedule the Lynis nightly cron job (02:00 daily, owned by `sebastian`).

After running the security playbook, re-run the grafana-agents playbook to push the extended `config.alloy` (with the CrowdSec scrape block and Lynis file-tail) to all nodes.

---

## Security Considerations

- `ansible/vars/security-vault.yml` is Ansible Vault encrypted. The vault password is never committed.
- The `.env` file on each node is written with `mode: 0600`, owned by `sebastian`.
- The firewall bouncer runs with `NET_ADMIN` and `NET_RAW` capabilities and `network_mode: host`. This is required for iptables/nftables rule injection.
- The Lynis container mounts `/:/hostfs:ro` and `--pid=host` to audit the actual host OS. It has no persistent write access beyond `/var/log/lynis/` and `/var/lib/node_exporter/textfile_collector/`.
- CrowdSec mounts `/var/log:/var/log:ro` — read-only access to host logs only.
