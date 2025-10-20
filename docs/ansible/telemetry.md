# Ansible Playbook - Telemetry

The telemetry playbook is responsible for provisioning and configuring the core telemetry infrastructure on the [`admin-pi`](../nodes/raspi/index.md) node. The `admin-pi` acts as the central hub for collection, analysis, and visualization.

## What it does

- **Monitoring Infrastructure**: Deploys the complete [telemetry](https://github.com/sommerfeld-io/telemetry) monitoring stack exclusively on the `admin-pi` for centralized observability
