# Ansible Playbook - Grafana Agents

This Ansible playbook deploys and configures Grafana Alloy telemetry collection agents on managed infrastructure nodes. It establishes the data collection layer for the observability stack by installing native system services on target hosts.

The playbook configures Grafana Alloy to collect metrics, logs, and traces from host systems and push the telemetry data to Grafana Cloud endpoints for centralized monitoring and analysis.

- **Agent Installation**: Deploys Grafana Alloy as a native system service on managed nodes
- **Telemetry Collection**: Configures Alloy to collect metrics, logs, and traces from the host system
- **Data Pipeline**: Sets up the data pipeline to push telemetry to Grafana Cloud's Prometheus and Loki endpoints
- **Secure Authentication**: Uses encrypted Vault credentials for secure authentication with Grafana Cloud

The playbook targets Ubuntu desktop and Raspberry Pi hosts (`ubuntu_desktop:raspi`) to establish comprehensive telemetry collection across the home lab infrastructure.
