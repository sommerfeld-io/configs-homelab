# Ansible Playbook - Telemetry-Stack

The telemetry playbook is responsible for setting up the monitoring stack.

- Deploy the central monitoring components onto the [`admin-pi`](../nodes/raspi/raspi-fleet.md).

This setup creates a distributed monitoring system where each node provides its own metrics, while the `admin-pi` acts as the central hub for collection, analysis, and visualization.
