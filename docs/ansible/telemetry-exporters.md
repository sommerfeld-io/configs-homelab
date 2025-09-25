# Ansible Playbook - Telemetry-Exporters

The telemetry playbook is responsible for setting metrics collection infrastructure across the environment.

- Installs and configures metrics exporters (all machines & Raspberry Pi nodes)
- Ensures that every machine and Raspberry Pi node in the environment exposes system and application metrics in a standardized way.

This setup creates a distributed monitoring system where each node provides its own metrics, while the `admin-pi` acts as the central hub for collection, analysis, and visualization.
