# `admin-pi.fritz.box`

The `admin-pi` consolidates monitoring and logging data from all our Linux nodes, including other Raspberry Pi nodes and Ubuntu workstations. It achieves this by running a powerful trio of open-source tools:

- **Prometheus:** This tool is the foundation of the monitoring system. It collects metrics from all your hosts (e.g. CPU usage, memory, disk I/O) and stores them in a time series database, allowing for historical analysis and trend tracking.
- **Grafana:** As the visualization layer, Grafana takes the metrics from Prometheus and transforms them into interactive and insightful dashboards. You can build custom graphs and charts to get a clear, at-a-glance view of your network's health and performance.
- **Loki:** This logging service is designed specifically for handling large volumes of log data efficiently. Loki works by using the same labels as Prometheus, which makes it easy to correlate metrics and logs for quick troubleshooting and root cause analysis.

The entire setup of the `admin-pi` is automated using Ansible playbooks. This ensures a consistent, repeatable, and documented process. The playbooks handle everything from installing the necessary software to configuring and starting the services, meaning we can easily redeploy the `admin-pi` or scale our observability stack with minimal manual effort.

## Setup Todos

In addition to the tasks listed in the [Setup Guide](index.md), please complete the following steps:

- [ ] Setup password-less ssh connections from `admin-pi`
    - [ ] `ssh-copy-id sebastian@caprica.fritz.box`
    - [ ] `ssh-copy-id sebastian@kobol.fritz.box`
