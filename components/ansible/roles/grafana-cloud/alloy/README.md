# Role: Alloy

This role deploys and configures Grafana Alloy to collect telemetry data and push it to Grafana Cloud. Alloy is installed as a native system service and runs on port 12345.

All sensitive credentials are stored in an encrypted Ansible Vault file. The vault file is safe to commit to the repository.

## Required Variables (from Ansible Vault)

The following sensitive variables must be defined in `vars/main.yml` (encrypted with Ansible Vault):

| Variable                       | Description                              |
|--------------------------------|------------------------------------------|
| `alloy_grafana_cloud_api_key`  | Grafana Cloud API key for authentication |
| `alloy_prometheus_user`        | Prometheus user ID for metrics push      |
| `alloy_loki_user`              | Loki user ID for logs push               |

**Note:** These variables are stored in an encrypted Ansible Vault file at `vars/main.yml`.
