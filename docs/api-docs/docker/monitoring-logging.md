# Docker Stack - Monitoring and Logging

This Docker Compose configuration represents the comprehensive monitoring stack for the homelab environment. The stack should provide the following features:

- Collect and visualize system metrics from workstations and Raspberry Pi nodes on the homelab
- Visualize website and service status (up / down)
- Collect and visualize metrics from the Talos Kubernetes Cluster

## Runtime Environment

The entire monitoring stack is intended to run on a Raspberry Pi node named `admin-pi.fritz.box`. This means that the Raspberry Pi serves as the central hub for the monitoring infrastructure.

## Components

| Component         | Port | URL                     | Info          |
| ----------------- | ---- | ----------------------- | ------------- |
| Prometheus        | 9090 | <http://localhost:9100> | -             |
| Grafana           | 3000 | <http://localhost:9110> | -             |
| Blackbox Exporter | 9115 | <http://localhost:9990> | -             |
| nginx             | 80   | <http://localhost>      | Reverse Proxy |

[Prometheus](https://prometheus.io/) is an open-source monitoring and alerting toolkit designed for reliability and scalability. In this stack, Prometheus serves as the core component responsible for collecting and storing metrics from various sources on the homelab, including nodes and workstations.

[Grafana](https://grafana.com/) is a popular open-source platform for monitoring and observability. It provides a powerful interface for creating interactive and customizable dashboards. Grafana integrates seamlessly with Prometheus, allowing you to visualize the data collected by Prometheus in the form of graphs, charts, and alerts.

Apart from Prometheus and Grafana, this stack includes other containers responsible for additional tasks like routing all HTTP requests through a reverse proxy.
