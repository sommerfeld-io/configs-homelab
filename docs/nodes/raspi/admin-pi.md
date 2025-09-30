# `admin-pi.fritz.box`

The `admin-pi` is a Raspberry Pi 4B with 4GB of RAM and a 128GB microSD card. It helps with administrative tasks in the home lab.

## Ansible Control Node

The `admin-pi` is a special machine that can connect to the other raspi nodes as well as to the Ubuntu workstations. All other raspi nodes do not have any special ssh config. Administrative todos are reserved for the `admin-pi` and the Ubuntu workstations.

The `admin-pi` is capable of running Ansible playbooks to manage other nodes in the home lab. It can run all the same playbooks as the Ubuntu desktop workstations.

## Monitoring and Logging Hub

The `admin-pi` consolidates monitoring and logging data from all Linux nodes, including other Raspberry Pi nodes and Ubuntu workstations. It achieves this by running a powerful trio of open-source tools:

- [Prometheus](https://prometheus.io): This tool is the foundation of the monitoring system. It collects metrics from all hosts (e.g. CPU usage, memory, disk I/O) and stores them in a time series database, allowing for historical analysis and trend tracking.
- [Grafana](https://grafana.com): As the visualization layer, Grafana takes the metrics from Prometheus and transforms them into interactive and insightful dashboards. You can build custom graphs and charts to get a clear, at-a-glance view of your network's health and performance.
- [Loki](https://grafana.com/oss/loki): This logging service is designed specifically for handling large volumes of log data efficiently. Loki works by using the same labels as Prometheus, which makes it easy to correlate metrics and logs for quick troubleshooting and root cause analysis.

The entire setup of the `admin-pi` is automated using Ansible playbooks. This ensures a consistent, repeatable, and documented process. The playbooks handle everything from installing the necessary software to configuring and starting the services, meaning we can easily redeploy the `admin-pi` or scale the observability stack with minimal manual effort.

## Setup

To automate the setup of `admin-pi`, should run the following Ansible playbooks:

- [ ] [Playbook "raspi"](../../ansible/raspi.md)
- [ ] [Playbook "repositories"](../../ansible/repositories.md)
- [ ] [Playbook "telemetry-exporters"](../../ansible/telemetry-exporters.md)

Running these playbooks ensures a consistent, repeatable, and fully documented deployment process for your monitoring infrastructure.

In addition to the tasks listed in the [Setup Guide](index.md) and Ansible playbooks, please complete the following steps:

- [ ] Setup password-less ssh connections from `admin-pi`
    - [ ] `ssh-copy-id sebastian@caprica.fritz.box`
    - [ ] `ssh-copy-id sebastian@kobol.fritz.box`
    - [ ] `ssh-copy-id sebastian@admin-pi.fritz.box` (to allow Ansible runs against this host)
