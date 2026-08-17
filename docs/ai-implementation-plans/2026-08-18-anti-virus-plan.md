# Security Monitoring & Intrusion Prevention – Implementation Plan

> **Scope:** 5 Raspberry Pi Ubuntu Server nodes (`pi4-01.fritz.box`, `pi4-02.fritz.box`, `pi4-03.fritz.box`, `pi4-05.fritz.box`, `pi5-01.fritz.box`)
> **Status:** Open – no code changes yet.
>
> **Phase:** Detection and monitoring only. No active blocking or firewall changes are in scope for this phase.
>
> **GiHub Issue:** <https://github.com/sommerfeld-io/configs-homelab/issues/305>
---

## 1. Overview

This plan integrates **CrowdSec** (real-time behavioural intrusion detection) and **Lynis** (nightly system auditing) across the five `raspi` inventory nodes. All containers run from a dedicated `docker-compose.yml` deployed by a standalone Ansible playbook. Metrics and logs flow through the existing **Grafana Alloy** pipeline to Grafana Cloud (Loki + Prometheus).

**This phase is detection and monitoring only.** The firewall bouncer (active IP blocking via iptables/nftables) is intentionally excluded. It will be considered in a later phase once the detection signal has been validated through dashboards.

### Design Principles (established constraints)

1. **No Python/shell HTTP middleware.** No custom exporter scripts, Pushgateway, or ad-hoc HTTP servers. Only dedicated, purpose-built exporter containers (e.g., cAdvisor) or Alloy built-in exporters are permitted.
2. **Alloy scrapes exporters directly.** Every metrics source is a real Prometheus exporter endpoint that Alloy reaches via `prometheus.scrape`. There is no intermediary process between the exporter and Alloy.
3. **Alloy must not raise errors on absent data.** When a scrape target is unreachable (e.g., CrowdSec not yet deployed on a node, Lynis cron not yet run), Alloy logs `up=0` silently and does **not** forward empty metric sets to Grafana Cloud. This is the natural behaviour of `prometheus.scrape` + `prometheus.relabel` with a `keep` rule — if a target is down the only metric forwarded is `up=0`, which is acceptable and expected.
4. **A single shared `config.alloy` is deployed to all nodes.** All managed nodes (workstations and `raspi`) are similar enough that no per-host or per-inventory-group Alloy config is needed. The CrowdSec scrape block is included in the shared `config.alloy`; when CrowdSec is not running on a node, Alloy records `up=0` for that target, which is acceptable and expected.
5. **Dashboards must display data-freshness signals.** Every security dashboard must include **stat panels** showing "Metrics Last Received" and "Logs Last Received" per integration/node. These panels use `time() - timestamp(...)` for Prometheus metrics and `bytes_over_time` / `count_over_time` for Loki logs. Colour thresholds: **green** when within expected scrape/cron interval, **yellow** when moderately stale, **red** when severely stale or absent.

Two Grafana dashboards (summary + per-node details) will live under `grafana-cloud/manifests/git-sync/security/`.

---

## 2. Repository Changes at a Glance

```
ansible/
  playbooks/
    deploy-security-stack.yml          ← new standalone playbook
  roles/
    security/
      crowdsec-lynis/
        defaults/
          main.yml                     ← role variables with defaults
        files/
          docker-compose.yml           ← single compose file (CrowdSec + Lynis + exporters)
          crowdsec-config.yml         ← CrowdSec log source / acquisition config
        tasks/
          main.yml                     ← orchestration task list
          cron.yml                     ← Lynis scheduled tasks (cron)
  vars/
    security.yml                       ← non-secret variables
    security-vault.yml                 ← non-encrypted secrets (CrowdSec API key, enroll token) ... encryption will be done manually later on. keep this instruction in mind no matter what is specified somewhere else in this document.

docs/
  nodes/
    raspi/
      security-monitoring.md          ← architecture documentation + PlantUML diagrams (NEW)

grafana-cloud/
  manifests/
    git-sync/
      security/
        _folder.json                   ← Grafana folder descriptor
        security-overview.json          ← Dashboard 1 – all-nodes summary - Name = "Security / Overview"
        security-details.json          ← Dashboard 2 – per-node deep-dive - Name = "Security / Details by Node"
```

The architecture and data-flow of the security monitoring stack is documented in prose and PlantUML diagrams in `docs/nodes/raspi/security-monitoring.md` and linked in the MkDocs site under **Raspberry Pi Nodes → Security Monitoring**.

---

## 3. Ansible Variables

### `ansible/vars/security.yml`

```yaml
# Path under which the security stack compose project is stored on each node
security_stack_dir: /opt/security-stack

# CrowdSec
crowdsec_lapi_port: 8080
crowdsec_metrics_port: 6060        # Prometheus metrics endpoint

# Lynis
lynis_report_dir: /var/log/lynis
lynis_schedule: "0 2 * * *"       # 02:00 every night
lynis_image: "cisofy/lynis"        # Official Lynis image from DockerHub

# Directory where the Lynis cron job writes Prometheus textfiles.
# Alloy's prometheus.exporter.unix textfile collector reads *.prom files from here.
lynis_textfile_dir: /var/lib/node_exporter/textfile_collector
```

### `ansible/vars/security-vault.yml`

```yaml
crowdsec_enroll_token: "{{ vault_crowdsec_enroll_token }}"
crowdsec_api_key: "{{ vault_crowdsec_api_key }}"
```

This is not a vault just yet! it will become a vault through manual steps later on!

---

## 4. Docker Compose – `ansible/roles/security/crowdsec-lynis/files/docker-compose.yml`

A **single** compose file holds every component:

| Service | Image | Port(s) | Purpose |
|---|---|---|---|
| `crowdsec` | `crowdsecurity/crowdsec:latest` | `8080` (LAPI, internal only), `127.0.0.1:6060` (metrics) | LAPI + behavioural engine |

> **Firewall bouncer excluded in this phase.** Active IP blocking (iptables/nftables) is out of scope. The detection-only setup gives full visibility via Grafana dashboards without modifying host firewall rules. The bouncer can be added later once detection signal is trusted.
>
> **No separate exporter container is needed.** Lynis metrics are written as Prometheus textfiles by the cron job and consumed directly by the Alloy `prometheus.exporter.unix` textfile collector already running on each node (see Section 8).

### Compose YAML outline

```yaml
---
services:

  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec
    restart: unless-stopped
    environment:
      - COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd
      - ENROLL_KEY=${CROWDSEC_ENROLL_TOKEN}
    volumes:
      - /var/log:/var/log:ro
      - crowdsec-db:/var/lib/crowdsec/data
      - crowdsec-config:/etc/crowdsec
      - ./crowdsec-config.yml:/etc/crowdsec/acquis.yaml:ro
    ports:
      - "${CROWDSEC_LAPI_PORT}:8080"
      - "127.0.0.1:${CROWDSEC_METRICS_PORT}:6060"   # metrics bound to localhost only
    healthcheck:
      test: ["CMD", "cscli", "version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

volumes:
  crowdsec-db:
  crowdsec-config:
```

**Environment file** (`.env` in `security_stack_dir`): populated by Ansible template with vault values.

---

## 5. CrowdSec Acquisition Config – `crowdsec-config.yml`

```yaml
---
filenames:
  - /var/log/auth.log
  - /var/log/syslog
  - /var/log/kern.log
labels:
  type: syslog

---
filenames:
  - /var/log/nginx/*.log
labels:
  type: nginx
```

All log files are bind-mounted into the `crowdsec` container as read-only (`/var/log:/var/log:ro`).

---

## 6. Lynis – Scheduled Auditing via Cron

Lynis runs as an **ephemeral** Docker container triggered by cron. The cron job is owned by `default_user` (`sebastian`) and:

1. Spins up a `cisofy/lynis` container (official DockerHub image) with `--rm` — no inline package installation needed.
2. Runs `lynis audit system --quiet --cronjob --rootdir /hostfs` — the `--rootdir` flag is **required** so Lynis inspects the bind-mounted host filesystem (`/hostfs`) rather than the container's own root.
3. Writes the Lynis report to a bind-mounted host path (`lynis_report_dir`).
4. Parses the hardening index and writes a **Prometheus textfile** (`.prom`) atomically to `lynis_textfile_dir` on the host (write to a `.tmp` file, then `mv` to `.prom`). Alloy's `prometheus.exporter.unix` textfile collector picks this up on the next scrape — no Pushgateway required.
5. Redirects all stdout/stderr to `/var/log/lynis/lynis-run.log` so Alloy's file-tail source can capture the run logs even after the ephemeral container exits.

### Cron job (Ansible task)

```yaml
- name: Security  ----  Lynis  ----  Schedule nightly audit
  ansible.builtin.cron:
    name: "lynis nightly audit"
    minute: "0"
    hour: "2"
    job: >
      HOST_HOSTNAME=$(hostname) &&
      docker run --rm
        -v /var/log/lynis:/var/log/lynis
        -v /var/lib/node_exporter/textfile_collector:/textfile_collector
        -v /:/hostfs:ro
        -e HOST_HOSTNAME="$HOST_HOSTNAME"
        --pid=host --network=host
        cisofy/lynis
        /bin/sh -c "
          lynis audit system --quiet --cronjob --rootdir /hostfs
            --logfile /var/log/lynis/lynis.log
            --report-file /var/log/lynis/lynis-report.dat &&
          SCORE=\$(grep hardening_index /var/log/lynis/lynis-report.dat | cut -d= -f2) &&
          printf '# HELP lynis_hardening_index Lynis system hardening index (0-100)\n# TYPE lynis_hardening_index gauge\nlynis_hardening_index{instance=\"%s\",job=\"integrations/node_exporter\"} %s\n' \"\$HOST_HOSTNAME\" \"\$SCORE\" > /textfile_collector/lynis.prom.tmp &&
          mv /textfile_collector/lynis.prom.tmp /textfile_collector/lynis.prom
        " >> /var/log/lynis/lynis-run.log 2>&1
    user: "{{ default_user }}"
```

**Key fixes applied:**

- **`cisofy/lynis` image** — the official Lynis image from DockerHub; no `apt-get install` needed, pinned version, faster startup.
- **`--rootdir /hostfs`** — without this flag Lynis audits the container's own root, not the host. The mount is `/:/hostfs:ro`; `--rootdir` directs Lynis to use it.
- **`HOST_HOSTNAME=$(hostname)`** — the host hostname is captured on the host before `docker run` and passed in as an environment variable (`-e HOST_HOSTNAME`). Inside the container `$(hostname)` would return the container ID, not the Pi's hostname.
- **Atomic `.prom` write** — the textfile is written to `lynis.prom.tmp` first and then renamed to `lynis.prom`. A rename on the same filesystem is atomic; Alloy can never read a partial file.
- **`/var/log/lynis/` logfile path** — the bind-mount exposes this path inside the container, so the `--logfile` and `--report-file` flags write to the host-visible directory directly.

**How the metric reaches Grafana Cloud:**

1. The cron job writes `/var/lib/node_exporter/textfile_collector/lynis.prom` on the host.
2. Alloy's `prometheus.exporter.unix` component (already configured in `config.alloy`) is extended with a `textfile` block pointing at that directory.
3. On the next scrape cycle Alloy reads the `.prom` file and forwards `lynis_hardening_index` through the existing `prometheus.relabel "integrations_node_exporter"` → `prometheus.remote_write "metrics_service"` chain to Grafana Cloud Prometheus.

The Lynis report file at `/var/log/lynis/` is also readable by Alloy via a file-tail source (see Section 8).

---

## 7. Ansible Playbook – `ansible/playbooks/deploy-security-stack.yml`

```yaml
---
- name: Deploy Security Stack
  hosts: raspi
  gather_facts: true
  become: true
  vars_files:
    - ../vars/main.yml
    - ../vars/raspi.yml
    - ../vars/security.yml
    - ../vars/security-vault.yml
  tasks:
    - ansible.builtin.include_role:
        name: ../roles/security/crowdsec-lynis
```

### Role task outline – `tasks/main.yml`

1. **Create directory** `security_stack_dir` owned by `default_user`.
2. **Copy** `files/docker-compose.yml` → `{{ security_stack_dir }}/docker-compose.yml`.
3. **Copy** `files/crowdsec-config.yml` → `{{ security_stack_dir }}/crowdsec-config.yml`.
4. **Template** `.env` file from vault values into `{{ security_stack_dir }}/.env` (mode `0600`, owner `{{ default_user }}`).
5. **Ensure** `/var/log/lynis` and `/var/lib/node_exporter/textfile_collector` directories exist (mode `0755`).
6. **Start** stack using `community.docker.docker_compose_v2`.
7. **Restart** stack when any config file changes (`register: compose_file`, `when: compose_file.changed`).
8. **Assert** `crowdsec` container is running.
9. **Include** `tasks/cron.yml` to install the Lynis cron job.

---

## 8. Grafana Alloy Integration

The existing `config.alloy` already collects Docker container logs (`loki.source.docker`) and forwards to Grafana Cloud Loki. The security stack benefits from this **immediately** without code changes for CrowdSec container log collection.

### 8.1 Lynis metrics – textfile collector extension

The `prometheus.exporter.unix` block already defined in `config.alloy` is extended with a `textfile` stanza so Alloy picks up `/var/lib/node_exporter/textfile_collector/lynis.prom` written by the cron job.

**No separate exporter container or HTTP server is used.** The textfile collector is a built-in capability of Alloy's `prometheus.exporter.unix` component — the cron job simply writes a `.prom` file and Alloy reads it directly on the next scrape cycle.

```alloy
prometheus.exporter.unix "integrations_node_exporter" {
  disable_collectors = ["ipvs", "btrfs", "infiniband", "xfs", "zfs"]

  // --- existing filesystem / netclass / netdev blocks unchanged ---

  textfile {
    directory = "/var/lib/node_exporter/textfile_collector"
  }
}
```

**Behaviour when Lynis has not run yet (or textfile is absent):** `prometheus.exporter.unix` simply emits no `lynis_hardening_index` metric. The relabel + remote-write chain forwards nothing for that metric — no errors in Alloy, no empty series in Grafana Cloud. The "Metrics Last Received" dashboard panel will show red until the first cron run completes, which is the correct expected behaviour.

`lynis_hardening_index` flows through the **existing** scrape/relabel/remote-write chain:

```
prometheus.exporter.unix  →  discovery.relabel "integrations_node_exporter"
  →  prometheus.scrape "integrations_node_exporter"
  →  prometheus.relabel "integrations_node_exporter"
  →  prometheus.remote_write "metrics_service"  (Grafana Cloud)
```

The metric carries `job="integrations/node_exporter"` and `instance=<hostname>`, so it lands in the same Prometheus namespace as all other node metrics — no new scrape target or remote-write endpoint required.

### 8.2 CrowdSec metrics – new Alloy scrape block

Alloy scrapes CrowdSec's built-in Prometheus endpoint directly at `localhost:6060/metrics`. **No wrapper, middleware, or custom HTTP server is involved.**

> **Deployment scope:** This block is added to the shared `config.alloy` deployed to all nodes. No per-host or per-inventory-group template split is required — all managed nodes are similar enough to share a single config. On nodes where CrowdSec is not running, Alloy records `up=0` for this target; this is intentional and allows dashboards to reflect the service state.

Append to the shared `config.alloy` template:

```alloy
/*
 * CrowdSec metrics – scraped directly from CrowdSec's built-in Prometheus endpoint.
 * When CrowdSec is not running (target unreachable), Alloy records up=0 and does NOT
 * forward any metric set to Grafana Cloud. No Alloy errors are raised for a down target.
 */
discovery.relabel "integrations_crowdsec" {
  targets = [{
    __address__      = "localhost:6060",
    __metrics_path__ = "/metrics",
    __scheme__       = "http",
  }]
  rule {
    target_label = "instance"
    replacement  = constants.hostname
  }
  rule {
    target_label = "job"
    replacement  = "integrations/crowdsec"
  }
}

prometheus.scrape "integrations_crowdsec" {
  targets         = discovery.relabel.integrations_crowdsec.output
  forward_to      = [prometheus.relabel.integrations_crowdsec.receiver]
  job_name        = "integrations/crowdsec"
  scrape_interval = "30s"
  scrape_timeout  = "10s"
}

prometheus.relabel "integrations_crowdsec" {
  forward_to = [prometheus.remote_write.metrics_service.receiver]
  rule {
    source_labels = ["__name__"]
    regex         = "cs_active_decisions|cs_alerts|cs_buckets|cs_cache_size|cs_lapi_decisions|up"
    action        = "keep"
  }
}
```

**Behaviour when CrowdSec is not yet deployed on a node:** `prometheus.scrape` marks the target as `up=0`. The `keep` relabel rule passes only `up` and the listed `cs_*` metrics. Since none of the `cs_*` metrics exist when the target is down, only `up=0` is forwarded — which is intentional and allows the dashboard to show "CrowdSec not running". Alloy logs a single "context deadline exceeded" debug message per scrape cycle; this is expected and not an error condition.

> The existing `grafana-agents.yml` playbook copies `config.alloy` to `/etc/alloy/config.alloy` and restarts the service. The CrowdSec scrape block is part of the shared template and requires no conditional guard — `up=0` on non-security nodes is an acceptable, expected state.

### 8.3 Ephemeral container logs

The ephemeral `docker run --rm` Lynis container exits before Alloy's `loki.source.docker` can discover it. The cron job appends all stdout/stderr to `/var/log/lynis/lynis-run.log` on the host (via `>> /var/log/lynis/lynis-run.log 2>&1`). An **Alloy file-tail** source tails this file:

```alloy
/*
 * Lynis audit run logs (from ephemeral cron container).
 * When no audit has run yet the file does not exist; loki.source.file silently watches
 * for it without raising errors. Logs are forwarded only when lines are appended.
 */
loki.source.file "lynis_audit_logs" {
  targets = [{
    __path__ = "/var/log/lynis/lynis-run.log",
    job      = "integrations/security",
    instance = constants.hostname,
  }]
  forward_to = [loki.write.grafana_cloud_loki.receiver]
}
```

The `alloy` system user can read `/var/log/lynis/` because the Ansible task creates it with `mode: 0755`. If the log file does not yet exist, `loki.source.file` waits silently — no error is emitted and nothing is forwarded to Grafana Cloud until the file appears.

---

## 9. Grafana Cloud Dashboards

### 9.1 Folder Descriptor – `grafana-cloud/manifests/git-sync/security/_folder.json`

```json
{
  "title": "Security",
  "uid": "security-folder"
}
```

### 9.2 Data Freshness Stat Panels (required in every security dashboard)

Every dashboard **must** include a dedicated **"Data Freshness"** row with stat panels that show when metrics and logs were last successfully received. These panels are the primary mechanism for detecting a silent failure (exporter down, cron not running, Alloy scrape issue) before it causes a security blind spot.

#### Colour thresholds (applied uniformly)

| State | Condition | Colour |
| --- | --- | --- |
| Green | Received within expected interval | `green` |
| Yellow | Moderately stale (2× expected interval) | `yellow` |
| Red | Severely stale or no data | `red` |

#### Prometheus "Metrics Last Received" panels

Each panel uses:

```promql
time() - timestamp(up{job="<job>", instance=~"$node"})
```

Unit: `s` (seconds). `reduceOptions.calcs = ["lastNotNull"]`.

| Panel title | Job label | Expected interval | Green < | Yellow < | Red ≥ |
| --- | --- | --- | --- | --- | --- |
| Metrics Last Received – CrowdSec | `integrations/crowdsec` | 30 s scrape | 120 s | 300 s | 300 s |
| Metrics Last Received – Node Exporter | `integrations/node_exporter` | default 60 s | 180 s | 600 s | 600 s |
| Metrics Last Received – Lynis Hardening Index | `integrations/node_exporter` + metric `lynis_hardening_index` | 24 h cron | 86 400 s | 172 800 s | 172 800 s |

For the Lynis panel specifically, the query is:

```promql
time() - timestamp(lynis_hardening_index{instance=~"$node"})
```

This returns "no data" until the first cron run completes (correct — the panel shows red with `noValue` mapped to a red status badge labelled "Not yet run").

#### Loki "Logs Last Received" panels

Each panel uses the **Loki** datasource with a range query that returns the age of the most recent log line:

```logql
# Time since last log line (in seconds) – adapt stream selector per source
max_over_time(
  {job="integrations/security", instance="$node"}
    | unwrap __timestamp__ [6h]
) by (instance)
```

In practice the Grafana Loki datasource does not support `__timestamp__` unwrapping directly for "last received" use cases. The recommended approach instead is a **Stat panel with the Loki datasource** that queries:

```logql
count_over_time({job="integrations/security", instance=~"$node"}[15m])
```

- If result > 0 → green ("Logs received in last 15 m")
- If result = 0 → red ("No logs in last 15 m")

For Lynis (nightly cron) use `[25h]` window instead of `[15m]`.

| Panel title | Log stream | Window | Green | Red |
| --- | --- | --- | --- | --- |
| Logs Last Received – Lynis Audit | `{job="integrations/security"}` | `[25h]` | > 0 | = 0 |
| Logs Last Received – CrowdSec Container | `{job="integrations/docker", container="crowdsec"}` | `[15m]` | > 0 | = 0 |

### 9.3 Dashboard 1 – Security Summary (`security-overview.json`)

**Purpose:** High-level security health across all 5 Raspberry Pi nodes.

**UID:** `security-raspi-summary`

**Rows and Panels:**

#### Row: Data Freshness

Stat panels as defined in Section 9.2 — one stat panel per integration (CrowdSec metrics, node_exporter metrics, Lynis hardening index metric, Lynis audit logs, CrowdSec container logs), with instance templated as `$node` (or repeated for all nodes in the summary view using `repeat: instance`).

#### Row: Fleet Status

| # | Panel type | Title | Query / Metric |
| --- | --- | --- | --- |
| 1 | Stat (one per node) | CrowdSec Status – All Nodes | `up{job="integrations/crowdsec"}` per instance – green 1, red 0 |
| 2 | Bar gauge | Hardening Index – All Nodes | `lynis_hardening_index` – <50 red, 50–74 orange, ≥75 green |
| 3 | Stat | Total Detected Decisions (fleet) | `sum(cs_active_decisions)` |
| 4 | Stat | Nodes with Active Detections | `count(cs_active_decisions > 0)` |

#### Row: Threat Overview

| # | Panel type | Title | Query / Metric |
| --- | --- | --- | --- |
| 5 | Status History | SSH Brute-Force Detections | `cs_active_decisions{reason=~"crowdsecurity/ssh-bf.*"}` per instance |
| 6 | Status History | Port Scan Detections | `cs_active_decisions{reason=~"crowdsecurity/portscan.*"}` per instance |
| 7 | Status History | HTTP Attack Detections | `cs_active_decisions{reason=~"crowdsecurity/http.*"}` per instance |
| 8 | Time series | Alerts Over Time (fleet) | `sum by (instance) (increase(cs_alerts[1h]))` |

#### Row: Recent Events

| # | Panel type | Title | Query / Metric |
| --- | --- | --- | --- |
| 9 | Table | Recent Decisions | Loki: `{job="integrations/docker", container="crowdsec"} \|= "decision"` |
| 10 | Bar chart | Outdated Packages per Node | `node_update_outdated_packages_count` (node_exporter apt-update collector) |

**Variables:** `$prometheus_datasource`, `$loki_datasource`, time range.

### 9.4 Dashboard 2 – Security Details (`security-details.json`)

**Purpose:** Deep-dive into a single selected node.

**UID:** `security-raspi-details`

**Template variables:**

- `$node` – instance selector: `label_values(up{job="integrations/crowdsec"}, instance)`

**Rows and Panels:**

#### Row: Data Freshness (required)

All stat panels from Section 9.2, scoped to `instance="$node"`:

| Panel title | Datasource | Thresholds |
| --- | --- | --- |
| Metrics Last Received – CrowdSec | Prometheus | green < 120 s, yellow < 300 s, red ≥ 300 s |
| Metrics Last Received – Node Exporter | Prometheus | green < 180 s, yellow < 600 s, red ≥ 600 s |
| Metrics Last Received – Lynis Hardening Index | Prometheus | green < 86 400 s, yellow < 172 800 s, red ≥ 172 800 s |
| Logs Last Received – Lynis Audit | Loki | green count > 0 in [25h], red = 0 |
| Logs Last Received – CrowdSec Container | Loki | green count > 0 in [15m], red = 0 |

#### Row: Node Status

| # | Panel type | Title | Query / Metric |
| --- | --- | --- | --- |
| 1 | Stat | CrowdSec Status | `up{job="integrations/crowdsec", instance="$node"}` |
| 2 | Stat | Lynis Hardening Index | `lynis_hardening_index{instance="$node"}` – <50 red, 50–74 orange, ≥75 green |
| 3 | Stat | Active Detected Decisions | `cs_active_decisions{instance="$node"}` |
| 4 | Stat | Active Alerts | `cs_alerts{instance="$node"}` |
| 5 | Gauge | Outdated Packages | `node_update_outdated_packages_count{instance="$node"}` |

#### Row: Threat Detail

| # | Panel type | Title | Query / Metric |
| --- | --- | --- | --- |
| 6 | Status History | SSH Brute-Force | `cs_active_decisions{instance="$node", reason=~"crowdsecurity/ssh-bf.*"}` |
| 7 | Status History | Port Scan | `cs_active_decisions{instance="$node", reason=~"crowdsecurity/portscan.*"}` |
| 8 | Status History | HTTP Attacks | `cs_active_decisions{instance="$node", reason=~"crowdsecurity/http.*"}` |
| 9 | Time series | Decisions Over Time | `cs_lapi_decisions{instance="$node"}` |

#### Row: Logs

| # | Panel type | Title | Query / Metric |
| --- | --- | --- | --- |
| 10 | Logs panel | Lynis Audit Log | `{job="integrations/security", instance="$node"}` |
| 11 | Logs panel | CrowdSec Events | `{job="integrations/docker", container="crowdsec", instance="$node"}` |

---

## 10. File & Naming Convention Alignment

| Convention | Alignment |
| --- | --- |
| Filenames (kebab-case) | All new files use kebab-case (`.ls-lint.yml` enforced) |
| Folder structure | New role path `ansible/roles/security/crowdsec-lynis/` matches `.folderslintrc` patterns |
| YAML style | Top-level `---`, 2-space indent, no quoted booleans (`yamllint`) |
| Playbook structure | Mirrors `grafana-agents.yml` – single `hosts`, `become: true`, `vars_files`, `include_role` |
| Stack deploy path | `docker_stacks_dir` in `main.yml` is `/home/{{ default_user }}/.docker-stacks`; security uses `/opt/security-stack` to keep it system-owned and outside the user home |
| Exporters port range | cAdvisor uses `9110`; Ollama uses `9180`; CrowdSec metrics: `6060` – no conflicts with existing ports |
| No Python/shell HTTP servers | Lynis metrics delivered via textfile collector (`.prom` file written by cron); CrowdSec metrics served by CrowdSec's own built-in Prometheus endpoint. No custom exporter scripts or Pushgateway. |
| Alloy scrape pattern | Follows existing `discovery.relabel` → `prometheus.scrape` → `prometheus.relabel` → `prometheus.remote_write` chain |
| Alloy scrape scope | CrowdSec scrape block is part of the shared `config.alloy` deployed to all nodes. On nodes where CrowdSec is not running, `up=0` is the only metric forwarded — this is intentional and requires no conditional template split. |
| Alloy error behaviour | All `prometheus.scrape` blocks use explicit `scrape_interval` and `scrape_timeout`. When a target is unreachable, `up=0` is the only metric forwarded. No errors are raised; no empty metric sets are sent. |
| Cron user | All cron jobs assigned to `{{ default_user }}` (`sebastian`) per `hosts.yml` |
| Container log capture | `loki.source.docker` for long-running containers; `loki.source.file` for ephemeral container log files. `loki.source.file` silently waits if the log file does not yet exist. |
| Dashboard data freshness | Every security dashboard includes a "Data Freshness" row with Prometheus `time() - timestamp(up{...})` stat panels and Loki `count_over_time` stat panels. Thresholds: green/yellow/red as specified in Section 9.2. |
| No active blocking | Firewall bouncer is excluded. No `NET_ADMIN`/`NET_RAW` capabilities, no host-network containers, no iptables/nftables modifications in this phase. |
| Lynis image | Uses `cisofy/lynis` (official DockerHub image). No inline package installation; version is controlled by image tag. |
| Lynis host audit | `--rootdir /hostfs` passed to `lynis audit system` so the host OS is audited, not the container root. |
| Lynis hostname label | Host hostname captured outside the container (`$(hostname)`) and passed via `-e HOST_HOSTNAME` to avoid reading the container ID. |
| Lynis textfile atomicity | Written to `lynis.prom.tmp` then renamed to `lynis.prom` to prevent Alloy parsing a partial file. |

---

## 11. Implementation Steps (Ordered)

1. **Create vars files** – `ansible/vars/security.yml` (plain) and `ansible/vars/security-vault.yml` (Ansible Vault encrypted with `crowdsec_enroll_token`).
2. **Create Ansible role skeleton** – `ansible/roles/security/crowdsec-lynis/{defaults,files,tasks}/`.
3. **Write `files/docker-compose.yml`** – CrowdSec LAPI only (no bouncer); metrics port bound to `127.0.0.1:6060:6060` only.
4. **Write `files/crowdsec-config.yml`** – syslog + nginx log sources.
5. **Write `tasks/main.yml`** – directory, copy, template, docker-compose-v2, assert tasks; also create `/var/lib/node_exporter/textfile_collector/` and `/var/log/lynis/` if they do not exist.
6. **Write `tasks/cron.yml`** – Lynis ephemeral container cron job using `cisofy/lynis`; writes `lynis.prom` textfile atomically and appends run logs to `/var/log/lynis/lynis-run.log`.
7. **Write `playbooks/deploy-security-stack.yml`** – standalone playbook targeting `raspi`.
8. **Extend the shared Alloy config** – add `textfile` block to `prometheus.exporter.unix`, append the CrowdSec scrape stanza, and add the Lynis file-tail stanza. The same `config.alloy` is used for all nodes; no per-group template split is needed.
9. **Update `grafana-agents.yml`** playbook to deploy the updated shared `config.alloy` to all managed hosts (no conditional template guard required).
10. **Create dashboard folder** – `grafana-cloud/manifests/git-sync/security/_folder.json`.
11. **Create `security-overview.json`** – summary dashboard with Data Freshness row (stat panels for all integrations), Fleet Status row, Threat Overview row, and Recent Events row.
12. **Create `security-details.json`** – per-node dashboard with Data Freshness row (scoped to `$node`), Node Status row, Threat Detail row, and Logs row.
13. **Run linter** – `task lint` (yaml, ansible, alloy-config, filenames, folders).
14. **Deploy to test node** – target a single pi node first (`--limit pi4-01.fritz.box`) and validate that: CrowdSec scrape returns `up=1`, Lynis textfile is absent initially (no Alloy errors), first cron run produces `lynis_hardening_index` in Grafana Cloud, "Data Freshness" dashboard panels show expected green/red states.
15. **Full rollout** – run `deploy-security-stack.yml` against all `raspi` hosts.

---

## 12. Security Considerations

- `security-vault.yml` must be encrypted with Ansible Vault before committing. The `.gitignore` already ignores `.vault_pass`; the vault password itself is never committed.
- The `.env` file on each node is written with `mode: 0600` and owned by `default_user` to prevent world-readable secrets.
- The CrowdSec metrics port (`6060`) is bound to `127.0.0.1` only — it is not accessible from the local network.
- The firewall bouncer is **not deployed** in this phase. No `NET_ADMIN`/`NET_RAW` capabilities are granted and no iptables/nftables rules are modified.
- Lynis runs inside a container with `/:/hostfs:ro` and `--pid=host` to audit the actual host OS. The container is ephemeral (`--rm`) and has no persistent writable access to the host filesystem beyond `/var/log/lynis` and the textfile collector directory.

---

## 13. Future Work (Out of Scope for This Phase)

- **Grafana alerting rules** – once detection signal is understood via dashboards, add alert rules for `up{job="integrations/crowdsec"} == 0`, stale Lynis index, and spike in `cs_alerts`.
- **Firewall bouncer** – add `crowdsec-firewall-bouncer` to the compose file after validating CrowdSec decision quality. Note the bouncer must use `network_mode: host` and connect to CrowdSec at `http://localhost:8080` (not `http://crowdsec:8080`, which is not resolvable from a host-networked container).
- **`logrotate` for `/var/log/lynis/lynis-run.log`** – add a logrotate config to prevent unbounded log growth on long-running nodes.

---

## Finishing todos

- Update status in `docs/ai-implementation-plans/2026-08-18-anti-virus-plan.md` from "Open" to "Closed".
