# Role: Alloy

This role deploys and configures Grafana Alloy to collect telemetry data and push it to Grafana Cloud. Alloy is installed as a native system service and runs on port 12345.

All sensitive credentials are stored in an encrypted Ansible Vault file. The vault file is safe to commit to the repository.

## Required Variables

The following sensitive variables are be defined in `components/ansible/vars/grafana-cloud-vault.yml` (encrypted with Ansible Vault):

| Variable                        | Description                              |
|---------------------------------|------------------------------------------|
| `grafana_cloud_api_key`         | Grafana Cloud API key for authentication |
| `grafana_cloud_prometheus_user` | Prometheus user ID for metrics push      |
| `grafana_cloud_loki_user`       | Loki user ID for logs push               |
