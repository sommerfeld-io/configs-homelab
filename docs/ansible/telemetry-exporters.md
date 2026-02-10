# Ansible Playbook - Telemetry-Exporters

> **DEPRECATED:** This playbook is relevant to install agents and exporters for Prometheus, Grafana, Loki etc. onto nodes on the homelab. These components relate to the Grafana OSS stack on the `admin-pi`. **Once we switched to Grafana Cloud, this playbook and the corresponding project will be obsolete and eventually removed!**

The telemetry playbook is responsible for setting metrics collection infrastructure across the environment.

## What it does

- **Basic Services**: Configures services to expose logs and metrics on all Ubuntu desktop and Raspberry Pi nodes

The playbook creates a distributed monitoring system where each node provides its own metrics, while the `admin-pi` acts as the central hub for collection, analysis, and visualization.
