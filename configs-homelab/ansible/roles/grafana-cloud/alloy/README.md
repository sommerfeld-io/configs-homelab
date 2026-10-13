# Role: Grafana Cloud / Alloy

This role deploys and configures Grafana Alloy to collect telemetry data and push it to Grafana Cloud. Alloy is installed as a native system service and runs on port `12345`.

Supports Debian (via the official Grafana APT repository, package/service/user `alloy`) and Arch Linux (via the `grafana-alloy` package from the `extra` repo, package/service/user `grafana-alloy`). OS-specific names are resolved automatically at the start of `tasks/main.yml`. On Arch, `/usr/bin/alloy` is symlinked to the `grafana-alloy` binary so the `alloy` command works there too.

All sensitive credentials are stored in an encrypted Ansible Vault file. The vault file is safe to commit to the repository.

> NOTE: `{{ default_user }}` will need `sudo` rights to run`systemctl start` without a password (a sudoers entry for that command). Otherwise the Cron Job to check and start Alloy if needed will no work.

## Labels

Every series and log line leaving a node carries the label `environment`, set as `external_labels` on `prometheus.remote_write` and `loki.write` in `templates/config.alloy.j2` from the variable `alloy_environment` (default `homelab`). The DigitalOcean inventory sets it to `digital-ocean`. It tells homelab nodes apart from the DigitalOcean droplet, whose own Alloy config (`configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`, selected with `alloy_config_template`) sets `environment=digital-ocean` and `stage`. The homelab has no `stage` label.

## Restarts

Alloy restarts through the `Restart Alloy` handler (with a systemd daemon reload), only when the config, the environment file, the systemd override, the GitHub token file, the binary capabilities or the docker group membership changed. A second run with nothing changed restarts nothing.

## Environments

There is one Alloy installer for the apartment (every fleet node, one shared config) and the DigitalOcean droplets. Two variables tell them apart:

- `alloy_config_template` selects the config. The default is this role's `templates/config.alloy.j2`. The DigitalOcean playbook sets it to `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`.
- `alloy_fleet_extras` (default `true`) gates the GitHub token file (`github.token`), the eBPF capabilities on the Alloy binary and the `AmbientCapabilities`/`CapabilityBoundingSet` lines in the systemd override. With `false`, a host that already has them loses them: the token file is deleted, `setcap -r` clears the binary capabilities, and the override is rewritten without the capability lines. Only use `false` together with a template that needs neither: the default fleet template reads `github.token` and runs `beyla.ebpf`, so Alloy breaks with `false` and the fleet template.

A relative `alloy_config_template` resolves against this role's `templates/` folder; callers outside the role pass an absolute path (the DigitalOcean playbook uses `{{ playbook_dir }}/../templates/alloy/config.alloy.j2`).

## Required Variables

| Variable                        | Description                                                                                     |
|---------------------------------|-------------------------------------------------------------------------------------------------|
| `default_user`                  | The user to install and configure for (typically the logged-in user)                            |
| `alloy_environment`             | Optional. Value of the `environment` label, default `homelab`                                   |
| `alloy_config_template`         | Optional. Template written to `config.alloy`, default `config.alloy.j2` (the fleet template)    |
| `alloy_fleet_extras`            | Optional. Fleet-only extras, default `true`; `false` removes them (see Environments)            |

The following sensitive variables are defined in `configs-homelab/ansible/vars/grafana-vault.yml` (encrypted with Ansible Vault):

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

<!-- ## What data is sent to Grafana Cloud as defined in `config.alloy`?

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
| **cAdvisor** (metrics)      | VS Code dev containers, linter containers, and non-allow-listed metric names | -->
