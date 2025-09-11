# Ansible Playbook - Telemetry

The telemetry playbook is responsible for setting up the monitoring and metrics collection infrastructure across the environment. It performs two main tasks:

- Provisioning Exporters (all machines & Raspberry Pi nodes)
    - Installs and configures metrics exporters
    - Ensures that every machine and Raspberry Pi node in the environment exposes system and application metrics in a standardized way.
- Provisioning the Monitoring Stack (`admin-pi`)
    - Deploys the central monitoring components onto the [`admin-pi`](../nodes/raspi/admin-pi.md).

This setup creates a distributed monitoring system where each node provides its own metrics, while the `admin-pi` acts as the central hub for collection, analysis, and visualization.
