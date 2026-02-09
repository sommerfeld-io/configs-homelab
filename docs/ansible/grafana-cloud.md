# Ansible Playbook - Grafana Cloud

This Ansible playbook performs comprehensive setup and configuration of Grafana Cloud observability for home lab infrastructure. It deploys telemetry collection agents on managed nodes and provisions dashboards in Grafana Cloud for monitoring and visualization.

The playbook consists of two plays: one for installing monitoring agents on target nodes, and another for provisioning the Grafana Cloud instance itself with dashboards and folder structures.

## What it does

- **Telemetry Collection**: Deploys Grafana Alloy as a native system service on managed nodes to collect metrics, logs, and traces
- **Data Pipeline**: Configures Alloy to push telemetry data to Grafana Cloud's Prometheus and Loki endpoints
- **Dashboard Provisioning**: Creates organized folder structures in Grafana Cloud for dashboard management
- **Pre-built Dashboards**: Imports industry-standard dashboards from Grafana.com (e.g., Node Exporter Full dashboard)
- **Secure Credentials**: All sensitive API keys and authentication credentials are stored in an encrypted Ansible Vault file

The playbook targets both infrastructure nodes (for agent deployment) and localhost (for cloud provisioning) to establish a complete observability solution for the home lab environment.
