# Grafana Cloud

This documentation covers the Ansible playbooks that establish the observability solution for the home lab infrastructure using Grafana Cloud. The playbooks deploy telemetry collection agents on managed nodes and provision dashboards in Grafana Cloud for comprehensive monitoring and visualization.

The implementation follows a modular approach with separate playbooks for agent deployment and cloud provisioning, orchestrated through a main playbook that coordinates the entire setup process.

All sensitive credentials and API keys are securely managed through Ansible Vault encryption.

## Ansible Playbook - Grafana

This Ansible playbook orchestrates the complete Grafana observability stack deployment for the home lab infrastructure. It serves as the main entry point for setting up comprehensive monitoring and telemetry collection across all managed nodes.

The playbook imports and executes two sub-playbooks in sequence:

- **Agent Deployment**: Imports `grafana-agents.yml` to install and configure Grafana Alloy on all managed infrastructure nodes
- **Cloud Provisioning**: Imports `grafana-cloud.yml` to provision dashboards and folder structures in Grafana Cloud

## Ansible Playbook - Grafana Agents

This Ansible playbook deploys and configures Grafana Alloy telemetry collection agents on managed infrastructure nodes. It establishes the data collection layer for the observability stack by installing native system services on target hosts.

The playbook configures Grafana Alloy to collect metrics, logs, and traces from host systems and push the telemetry data to Grafana Cloud endpoints for centralized monitoring and analysis.

- **Agent Installation**: Deploys Grafana Alloy as a native system service on managed nodes
- **Telemetry Collection**: Configures Alloy to collect metrics, logs, and traces from the host system
- **Data Pipeline**: Sets up the data pipeline to push telemetry to Grafana Cloud's Prometheus and Loki endpoints
- **Secure Authentication**: Uses encrypted Vault credentials for secure authentication with Grafana Cloud

The playbook targets Ubuntu desktop and Raspberry Pi hosts (`ubuntu_desktop:raspi`) to establish comprehensive telemetry collection across the home lab infrastructure.

## Ansible Playbook - Grafana Cloud

This Ansible playbook provisions the Grafana Cloud instance with dashboards and organizational structures for monitoring visualization. It executes on localhost to configure the cloud platform without requiring direct access to managed infrastructure nodes.

The playbook creates a structured dashboard hierarchy in Grafana Cloud and imports pre-built monitoring dashboards to provide immediate visibility into infrastructure health and performance.

- **Folder Structures**: Creates organized folder structures in Grafana Cloud for dashboard management
- **Dashboard Import**: Imports pre-built dashboards from Grafana.com (e.g., Node Exporter Full dashboard)
- **Monitoring Visualization**: Provisions comprehensive dashboards for infrastructure monitoring
- **Secure Credentials**: Uses encrypted Vault credentials for Grafana Cloud API authentication

The playbook executes locally on the control machine to provision the Grafana Cloud instance (sommerfeldio.grafana.net) with a complete set of monitoring dashboards and organizational structures.

> **CAUION:** To not run this playbook on multiple nodes in parallel. This would create duplicate objects (dashboards, folders, etc.) in Grafana. However, running this playybook multiple time from localhost correctly detects existing objects in Grafana Cloud and does not create duplicates.
