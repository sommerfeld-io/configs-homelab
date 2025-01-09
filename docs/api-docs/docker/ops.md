---
hide:
  - toc
---

# Docker Stack - Ops

The `ops` Docker stack is a Docker Compose configuration that manages
all of the needed exporters to monitor system metrics with Prometheus and Grafana. By
using the `ops` Docker stack, you can quickly and easily deploy all of the necessary
components for monitoring your system metrics. This includes exporters for various system
metrics, such as CPU usage, disk usage, and network activity.

| Component     | Port | URL                   |
| ------------- | ---- | --------------------- |
| node_exporter | 9100 | <http://localhost:9100> |
| cAdvisor      | 9110 | <http://localhost:9110> |
