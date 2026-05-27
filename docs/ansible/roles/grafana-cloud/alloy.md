# Role: Grafana Cloud / Alloy

This role deploys and configures Grafana Alloy to collect telemetry data and push it to Grafana Cloud. Alloy is installed as a native system service and runs on port `12345`.

All sensitive credentials are stored in an encrypted Ansible Vault file. The vault file is safe to commit to the repository.

> NOTE: `{{ default_user }}` will need `sudo` rights to run`systemctl start` without a password (a sudoers entry for that command). Otherwise the Cron Job to check and start Alloy if needed will no work.

## Required Variables

| Variable                        | Description                                                                                     |
|---------------------------------|-------------------------------------------------------------------------------------------------|
| `default_user`                  | The user to install and configure for (typically the logged-in user)                            |

The following sensitive variables are be defined in `components/ansible/vars/grafana-vault.yml` (encrypted with Ansible Vault):

| Variable                        | Description                                                                                     |
|---------------------------------|-------------------------------------------------------------------------------------------------|
| `grafana_com_url`               | The URL of the Grafana Instance (the one you access from the browser)                           |
| `grafana_cloud_api_key`         | Grafana Cloud API key for authentication                                                        |
| `grafana_cloud_prometheus_user` | Prometheus user ID for metrics push                                                             |
| `grafana_cloud_loki_user`       | Loki user ID for logs push                                                                      |
| `grafana_cloud_tempo_url`       | The URL to the Tempo datasource                                                                 |
| `grafana_cloud_tempo_user`      | The user of the Tempo datasource                                                                |
| `grafana_cloud_tempo_api_key`   | Scopes: `metrics:write`, `logs:write`, `traces:write`, `profiles:write`,`fleet-management:read` |

See <https://grafana.com/orgs/sommerfeldio/access-policies> for an overview of all tokens.

## What data is sent to Grafana Cloud as defined in `config.alloy`?

### Collected and sent to Grafana Cloud

| Integration                       | What is sent                                                                              |
|-----------------------------------|-------------------------------------------------------------------------------------------|
| **Node Exporter** (metrics)       | Host metrics (CPU, memory, disk, network), virtual FS and interfaces excluded             |
| **Alloy health** (metrics)        | Curated Alloy self-monitoring metrics (state, WAL, transport, resource usage)             |
| **Alloy logs** (logs)             | Alloy log output with extracted `level` label                                             |
| **systemd journal** (logs)        | Journal entries from the last 12h with `unit`, `boot_id`, `transport`, and `level` labels |
| **GitHub** (metrics)              | Repo and rate-limit metrics for orgs/users (only configured `github_*` and `up` metrics)  |
| **Beyla eBPF** (metrics + traces) | Auto-instrumented HTTP/HTTPS metrics and traces for configured ports                      |
| **Docker container logs** (logs)  | stdout/stderr logs from running containers with `container`, `instance`, and `job` labels |
| **cAdvisor** (metrics)            | Curated `container_*` and `machine_*` metrics from `localhost:9110`                       |
| **Ollama** (metrics)              | Metrics from `localhost:9180` - unavailable nodes only report `up=0`                      |

### Explicitly dropped / not sent

| Integration                 | What is dropped                                                              |
|-----------------------------|------------------------------------------------------------------------------|
| **Node Exporter** (metrics) | `node_scrape_collector_.+` metrics (internal scrape bookkeeping)             |
| **Docker logs** (logs)      | VS Code dev containers and short-lived linter containers                     |
| **cAdvisor** (metrics)      | VS Code dev containers, linter containers, and non-allow-listed metric names |
