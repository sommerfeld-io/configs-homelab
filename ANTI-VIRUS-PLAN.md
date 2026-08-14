# Security Monitoring & Intrusion Prevention – Implementation Plan

> **Scope:** 5 Raspberry Pi Ubuntu Server nodes (`pi4-01.fritz.box`, `pi4-02.fritz.box`, `pi4-03.fritz.box`, `pi4-05.fritz.box`, `pi5-01.fritz.box`)
> **Status:** Planning – no code changes yet.

---

## 1. Overview

This plan integrates **CrowdSec** (real-time behavioural intrusion detection) and **Lynis** (nightly system auditing) across the five `raspi` inventory nodes. All containers run from a dedicated `docker-compose.yml` deployed by a standalone Ansible playbook. Metrics and logs flow through the existing **Grafana Alloy** pipeline to Grafana Cloud (Loki + Prometheus). No additional exporter containers are needed: Alloy's built-in `prometheus.exporter.unix` **textfile collector** exposes the Lynis hardening index directly, and CrowdSec's own `/metrics` endpoint is scraped by Alloy. Two Grafana dashboards (summary + per-node details) will live under `grafana-cloud/manifests/git-sync/security/`.

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
          crowdsec-acquis.yaml         ← CrowdSec log source / acquisition config
        tasks/
          main.yml                     ← orchestration task list
          cron.yml                     ← Lynis scheduled tasks (cron)
  vars/
    security.yml                       ← non-secret variables
    security-vault.yml                 ← vault-encrypted secrets (CrowdSec API key, enroll token)

grafana-cloud/
  manifests/
    git-sync/
      security/
        _folder.json                   ← Grafana folder descriptor
        security-summary.json          ← Dashboard 1 – all-nodes summary
        security-details.json          ← Dashboard 2 – per-node deep-dive
```

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
lynis_image: "debian:bookworm-slim"

# Directory where the Lynis cron job writes Prometheus textfiles.
# Alloy's prometheus.exporter.unix textfile collector reads *.prom files from here.
lynis_textfile_dir: /var/lib/node_exporter/textfile_collector
```

### `ansible/vars/security-vault.yml` _(Ansible Vault encrypted)_

```yaml
crowdsec_enroll_token: "{{ vault_crowdsec_enroll_token }}"
crowdsec_api_key: "{{ vault_crowdsec_api_key }}"
```

---

## 4. Docker Compose – `ansible/roles/security/crowdsec-lynis/files/docker-compose.yml`

A **single** compose file holds every component:

| Service | Image | Port(s) | Purpose |
|---|---|---|---|
| `crowdsec` | `crowdsecurity/crowdsec:latest` | `8080`, `6060` | LAPI + behavioural engine |
| `crowdsec-firewall-bouncer` | `crowdsecurity/firewall-bouncer:latest` | – | Applies iptables/nftables bans |

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
      - ./crowdsec-acquis.yaml:/etc/crowdsec/acquis.yaml:ro
    ports:
      - "${CROWDSEC_LAPI_PORT}:8080"
      - "${CROWDSEC_METRICS_PORT}:6060"
    healthcheck:
      test: ["CMD", "cscli", "version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

  crowdsec-firewall-bouncer:
    image: crowdsecurity/firewall-bouncer:latest
    container_name: crowdsec-firewall-bouncer
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - CROWDSEC_LAPI_URL=http://crowdsec:8080
      - CROWDSEC_LAPI_KEY=${CROWDSEC_API_KEY}
    depends_on:
      crowdsec:
        condition: service_healthy

volumes:
  crowdsec-db:
  crowdsec-config:
```

**Environment file** (`.env` in `security_stack_dir`): populated by Ansible template with vault values.

---

## 5. CrowdSec Acquisition Config – `crowdsec-acquis.yaml`

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

1. Spins up a `debian:bookworm-slim` container with `--rm`.
2. Installs Lynis inline, runs `lynis audit system --quiet --cronjob`.
3. Writes the Lynis report to a bind-mounted host path (`lynis_report_dir`).
4. Parses the hardening index and writes a **Prometheus textfile** (`.prom`) to `lynis_textfile_dir` on the host. Alloy's `prometheus.exporter.unix` textfile collector picks this up on the next scrape — no Pushgateway required.
5. Redirects all stdout/stderr to `/var/log/lynis/lynis-run.log` so Alloy's file-tail source can capture the run logs even after the ephemeral container exits.

### Cron job (Ansible task)

```yaml
- name: Security  ----  Lynis  ----  Schedule nightly audit
  ansible.builtin.cron:
    name: "lynis nightly audit"
    minute: "0"
    hour: "2"
    job: >
      docker run --rm
        -v /var/log/lynis:/var/log/lynis
        -v /var/lib/node_exporter/textfile_collector:/textfile_collector
        -v /:/hostfs:ro
        --pid=host --network=host
        debian:bookworm-slim
        /bin/bash -c "
          apt-get update -qq && apt-get install -yqq lynis &&
          lynis audit system --quiet --cronjob --logfile /var/log/lynis/lynis.log --report-file /var/log/lynis/lynis-report.dat &&
          SCORE=\$(grep hardening_index /var/log/lynis/lynis-report.dat | cut -d= -f2) &&
          HOSTNAME=\$(hostname) &&
          printf '# HELP lynis_hardening_index Lynis system hardening index (0-100)\n# TYPE lynis_hardening_index gauge\nlynis_hardening_index{instance=\"%s\",job=\"integrations/node_exporter\"} %s\n' \"\$HOSTNAME\" \"\$SCORE\" > /textfile_collector/lynis.prom
        " >> /var/log/lynis/lynis-run.log 2>&1
    user: "{{ default_user }}"
```

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
3. **Copy** `files/crowdsec-acquis.yaml` → `{{ security_stack_dir }}/crowdsec-acquis.yaml`.
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

The `prometheus.exporter.unix` block already defined in `config.alloy` is extended with a `textfile` stanza so Alloy picks up `/var/lib/node_exporter/textfile_collector/lynis.prom` written by the cron job:

```alloy
prometheus.exporter.unix "integrations_node_exporter" {
  disable_collectors = ["ipvs", "btrfs", "infiniband", "xfs", "zfs"]

  // --- existing filesystem / netclass / netdev blocks unchanged ---

  textfile {
    directory = "/var/lib/node_exporter/textfile_collector"
  }
}
```

`lynis_hardening_index` flows through the **existing** scrape/relabel/remote-write chain:

```
prometheus.exporter.unix  →  discovery.relabel "integrations_node_exporter"
  →  prometheus.scrape "integrations_node_exporter"
  →  prometheus.relabel "integrations_node_exporter"
  →  prometheus.remote_write "metrics_service"  (Grafana Cloud)
```

The metric carries `job="integrations/node_exporter"` and `instance=<hostname>`, so it lands in the same Prometheus namespace as all other node metrics — no new scrape target or remote-write endpoint required.

### 8.2 CrowdSec metrics – new Alloy scrape block

Append to `config.alloy`:

```alloy
/*
 * CrowdSec metrics
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
  targets    = discovery.relabel.integrations_crowdsec.output
  forward_to = [prometheus.relabel.integrations_crowdsec.receiver]
  job_name   = "integrations/crowdsec"
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

> The existing `grafana-agents.yml` playbook copies `config.alloy` to `/etc/alloy/config.alloy` and restarts the service, so running that playbook after the Alloy changes are made will propagate them to all nodes.

### 8.3 Ephemeral container logs

The ephemeral `docker run --rm` Lynis container exits before Alloy's `loki.source.docker` can discover it. The cron job appends all stdout/stderr to `/var/log/lynis/lynis-run.log` on the host (via `>> /var/log/lynis/lynis-run.log 2>&1`). An **Alloy file-tail** source tails this file:

```alloy
/*
 * Lynis audit run logs (from ephemeral cron container)
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

The `alloy` system user can read `/var/log/lynis/` because the Ansible task creates it with `mode: 0755`.

---

## 9. Grafana Cloud Dashboards

### 9.1 Folder Descriptor – `grafana-cloud/manifests/git-sync/security/_folder.json`

```json
{
  "title": "Security",
  "uid": "security-folder"
}
```

### 9.2 Dashboard 1 – Security Summary (`security-summary.json`)

**Purpose:** High-level security health across all 5 Raspberry Pi nodes.

**UID:** `security-raspi-summary`

**Panels (row-by-row):**

| # | Panel type | Title | Query / Metric |
|---|---|---|---|
| 1 | Stat (5-cell table) | Node Status | `up{job="integrations/crowdsec"}` – green if 1, red if 0, per instance |
| 2 | Status History | Threat Detected – SSH Brute-Force | `cs_active_decisions{reason=~"crowdsecurity/ssh-bf.*"}` > 0 → red, else green |
| 3 | Status History | Threat Detected – Port Scan | `cs_active_decisions{reason=~"crowdsecurity/portscan.*"}` > 0 → red, else green |
| 4 | Status History | Threat Detected – HTTP Attacks | `cs_active_decisions{reason=~"crowdsecurity/http.*"}` > 0 → red, else green |
| 5 | Bar gauge | Hardening Index (all nodes) | `lynis_hardening_index` – colour-coded: <50 red, 50–74 orange, ≥75 green |
| 6 | Stat | Total Blocked IPs (fleet) | `sum(cs_active_decisions)` |
| 7 | Time series | Alerts Over Time (fleet) | `sum by (instance) (increase(cs_alerts[1h]))` |
| 8 | Stat | Nodes with Active Warnings | `count(cs_active_decisions > 0)` |
| 9 | Table | Recent CrowdSec Decisions | Loki query: `{job="integrations/docker", container="crowdsec"} |= "ban"` |
| 10 | Bar chart | Outdated Packages (per node) | `node_update_outdated_packages_count` from Node Exporter (if apt-update collector enabled) |

**Variables:** `$datasource` (Prometheus), `$loki_datasource`, time range.

### 9.3 Dashboard 2 – Security Details (`security-details.json`)

**Purpose:** Deep-dive into a single selected node.

**UID:** `security-raspi-details`

**Template variables:**
- `$node` – instance selector populated from `label_values(up{job="integrations/crowdsec"}, instance)`

**Panels:**

| # | Panel type | Title | Query / Metric |
|---|---|---|---|
| 1 | Stat | CrowdSec Status | `up{job="integrations/crowdsec", instance="$node"}` |
| 2 | Stat | Lynis Hardening Index | `lynis_hardening_index{instance="$node"}` |
| 3 | Stat | Active Blocked IPs | `cs_active_decisions{instance="$node"}` |
| 4 | Stat | Active Security Warnings | `cs_alerts{instance="$node"}` |
| 5 | Status History | Threat Detected – SSH Brute-Force | `cs_active_decisions{instance="$node", reason=~"crowdsecurity/ssh-bf.*"}` |
| 6 | Status History | Threat Detected – Port Scan | `cs_active_decisions{instance="$node", reason=~"crowdsecurity/portscan.*"}` |
| 7 | Status History | Threat Detected – HTTP Attacks | `cs_active_decisions{instance="$node", reason=~"crowdsecurity/http.*"}` |
| 8 | Time series | Decisions Over Time | `cs_lapi_decisions{instance="$node"}` |
| 9 | Gauge | Outdated Packages | `node_update_outdated_packages_count{instance="$node"}` |
| 10 | Logs panel | Lynis Audit Log | `{job="integrations/security", instance="$node"}` |
| 11 | Logs panel | CrowdSec Events | `{job="integrations/docker", container="crowdsec", instance="$node"}` |
| 12 | Text | Lynis Last Run | Annotation from Loki: `{job="integrations/security"} |= "Lynis audit run"` |

---

## 10. File & Naming Convention Alignment

| Convention | Alignment |
|---|---|
| Filenames (kebab-case) | All new files use kebab-case (`.ls-lint.yml` enforced) |
| Folder structure | New role path `ansible/roles/security/crowdsec-lynis/` matches `.folderslintrc` patterns |
| YAML style | Top-level `---`, 2-space indent, no quoted booleans (`yamllint`) |
| Playbook structure | Mirrors `grafana-agents.yml` – single `hosts`, `become: true`, `vars_files`, `include_role` |
| Stack deploy path | `docker_stacks_dir` in `main.yml` is `/home/{{ default_user }}/.docker-stacks`; security uses `/opt/security-stack` to keep it system-owned and outside the user home |
| Exporters port range | cAdvisor uses `9110`; Ollama uses `9180`; CrowdSec metrics: `6060` – no conflicts with existing ports |
| Lynis metrics delivery | Cron job writes `.prom` textfile to `lynis_textfile_dir`; Alloy `prometheus.exporter.unix` textfile collector reads it – no separate exporter container or push step |
| Alloy scrape pattern | Follows existing `discovery.relabel` → `prometheus.scrape` → `prometheus.relabel` → `prometheus.remote_write` chain |
| Cron user | All cron jobs assigned to `{{ default_user }}` (`sebastian`) per `hosts.yml` |
| Container log capture | `loki.source.docker` for long-running containers; `loki.source.file` for ephemeral container log files |

---

## 11. Implementation Steps (Ordered)

1. **Create vars files** – `ansible/vars/security.yml` (plain) and `ansible/vars/security-vault.yml` (Ansible Vault encrypted with `crowdsec_enroll_token`, `crowdsec_api_key`).
2. **Create Ansible role skeleton** – `ansible/roles/security/crowdsec-lynis/{defaults,files,tasks}/`.
3. **Write `files/docker-compose.yml`** – CrowdSec LAPI and firewall bouncer only; no exporter container.
4. **Write `files/crowdsec-acquis.yaml`** – syslog + nginx log sources.
5. **Write `tasks/main.yml`** – directory, copy, template, docker-compose-v2, assert tasks; also create `/var/lib/node_exporter/textfile_collector/` if it does not exist.
6. **Write `tasks/cron.yml`** – Lynis ephemeral container cron job; writes `lynis.prom` textfile and appends run logs to `/var/log/lynis/lynis-run.log`.
7. **Write `playbooks/deploy-security-stack.yml`** – standalone playbook targeting `raspi`.
8. **Extend `config.alloy`** – add `textfile` block to `prometheus.exporter.unix`, append CrowdSec scrape stanza, and add Lynis file-tail stanza.
9. **Update `grafana-agents.yml`** playbook if any Alloy-related vars need to be wired up (may not be necessary).
10. **Create dashboard folder** – `grafana-cloud/manifests/git-sync/security/_folder.json`.
11. **Create dashboard JSONs** – `security-summary.json` and `security-details.json` with panels as specified above.
12. **Run linter** – `task lint` (yaml, ansible, alloy-config, filenames, folders).
13. **Deploy to test node** – target a single pi node first (`--limit pi4-01.fritz.box`) and validate.
14. **Full rollout** – run `deploy-security-stack.yml` against all `raspi` hosts.

---

## 12. Security Considerations

- `security-vault.yml` must be encrypted with Ansible Vault before committing. The `.gitignore` already ignores `.vault_pass`; the vault password itself is never committed.
- The `.env` file on each node is written with `mode: 0600` and owned by `default_user` to prevent world-readable secrets.
- The firewall bouncer container requires `NET_ADMIN` and `NET_RAW` capabilities and runs with `network_mode: host`; this is expected and documented.
- Lynis runs inside a container with `/:/hostfs:ro` and `--pid=host` to audit the actual host OS. The container is ephemeral (`--rm`) and has no persistent writable access to the host filesystem beyond `/var/log/lynis`.
