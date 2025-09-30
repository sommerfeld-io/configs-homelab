# Ansible Playbook - Telemetry-Exporters

The telemetry playbook is responsible for setting metrics collection infrastructure across the environment.

## What it does

- **Basic Services**: Configures services to expose logs and metrics on all Ubuntu desktop and Raspberry Pi nodes

The playbook creates a distributed monitoring system where each node provides its own metrics, while the `admin-pi` acts as the central hub for collection, analysis, and visualization.
