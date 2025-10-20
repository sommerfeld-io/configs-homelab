# Raspberry Pi Nodes

The Raspberry Pi fleet consists of multiple Raspberry Pi devices that serve as lightweight nodes in the home lab infrastructure. These devices handle dedicated roles including administrative tasks, monitoring and logging aggregation, and testing environments.
y

## Rack Layout

Workstations and Raspberry Pi nodes are organized in a DeskPi RackMate T0, a compact 10-inch rack system. This setup keeps all devices securely mounted and easily accessible.

```ditaa
+-----------------+-----------------+
|  runner-04-pi   |  runner-05-pi   |
+-----------------+-----------------+
|  runner-06-pi5  |  admin-pi       |
+-----------------+-----------------+
|  Power and HDD                    |
+-----------------------------------+
|  caprica                          |
+-----------------------------------+
```

## Setup Guide

The entire setup of all Raspi nodes is automated using Ansible playbooks. This ensures a consistent, repeatable, and documented process. The playbooks handle everything from installing the necessary software to configuring and starting the services, meaning we can easily redeploy or scale with minimal manual effort.

Ubuntu Server is the operating system of choice for all RasPi Nodes.

### Installation and Configuration

* [ ] Use the RasPi Imager to install Ubuntu Server onto a SD card.
* [ ] Set `sebastian` as user and set the default password.
* [ ] Configure hostname, Wifi settings and enable SSH server with password-based auth.
* [ ] Insert the SD card into the Raspberry Pi and power it on.
* [ ] Connect to new Raspberry Pi via `ssh sebastian@<THE_HOSTNAME>.fritz.box` from all relevant machines.
* [ ] Setup password-less ssh connections via `ssh-copy-id sebastian@<THE_HOSTNAME>.fritz.box` from all relevant machines.
* [ ] Install machine using the Ansible configs from this repo using `task`.
    * [ ] [Playbook "raspi"](../../ansible/raspi.md)
    * [ ] [Playbook "repositories"](../../ansible/repositories.md)
    * [ ] [Playbook "telemetry-exporters"](../../ansible/telemetry-exporters.md)

### Follow-Up Todos

* [ ] Add the new RasPi Node to `components/ansible/assets/global-taskfile.yml` for easy SSH connections.
* [ ] Allow machine to work with GitHub. Use public key `id_rsa.pub`, NOT the private key!
* [ ] Login to Docker registry on the new machine: `docker login`

## RasPi Fleet Overview

The Raspberry Pi fleet consists of multiple Raspberry Pi devices that serve as lightweight nodes in the home lab infrastructure. These devices handle dedicated roles including administrative tasks, monitoring and logging aggregation, and testing environments. Each Pi is configured through automated Ansible playbooks to ensure consistent deployment and management across the entire fleet.

| Name            | Model           | RAM | Storage         | Note |
|-----------------|-----------------|-----|-----------------|------|
| `admin-pi`      | Raspberry Pi 4B | 8GB | 128GB microSD   | Help with administrative tasks in the home lab |
| `runner-04-pi`  | Raspberry Pi 4B | 8GB | 32GB microSD    | -    |
| `runner-05-pi`  | Raspberry Pi 4B | 8GB | 32GB microSD    | -    |
| `runner-06-pi5` | Raspberry Pi 5  | 8GB | 32GB microSD    | -    |

### `admin-pi.fritz.box`

* **Ansible Control Node**
    * The `admin-pi` is a special machine that can connect to the other raspi nodes as well as to the Ubuntu workstations. All other raspi nodes do not have any special ssh config. Administrative todos are reserved for the `admin-pi` and the Ubuntu workstations.
    * The `admin-pi` is capable of running Ansible playbooks to manage other nodes in the home lab. It can run all the same playbooks as the Ubuntu desktop workstations.
* **Monitoring and Logging Hub**
    * The `admin-pi` consolidates monitoring and logging data from all Linux nodes, including other Raspberry Pi nodes and Ubuntu workstations. It achieves this by running a powerful trio of open-source tools:
        * [Prometheus](https://prometheus.io): This tool is the foundation of the monitoring system. It collects metrics from all hosts (e.g. CPU usage, memory, disk I/O) and stores them in a time series database, allowing for historical analysis and trend tracking.
        * [Grafana](https://grafana.com): As the visualization layer, Grafana takes the metrics from Prometheus and transforms them into interactive and insightful dashboards. You can build custom graphs and charts to get a clear, at-a-glance view of your network's health and performance.
        * [Loki](https://grafana.com/oss/loki): This logging service is designed specifically for handling large volumes of log data efficiently. Loki works by using the same labels as Prometheus, which makes it easy to correlate metrics and logs for quick troubleshooting and root cause analysis.
* **Setup**: In addition to the tasks listed in the Setup Guide above, please complete the following steps:
    * [ ] [Playbook "telemetry"](../../ansible/telemetry.md)
    * [ ] Setup password-less ssh connections from `admin-pi`
        * [ ] `ssh-copy-id sebastian@caprica.fritz.box`
        * [ ] `ssh-copy-id sebastian@kobol.fritz.box`
        * [ ] `ssh-copy-id sebastian@admin-pi.fritz.box` (to allow Ansible runs against this host)
        * [ ] `ssh-copy-id sebastian@runner-04-pi.fritz.box`
        * [ ] `ssh-copy-id sebastian@runner-05-pi.fritz.box`
        * [ ] `ssh-copy-id sebastian@runner-06-pi5.fritz.box`

### `runner-04-pi.fritz.box`

* **Setup**: In addition to the tasks listed in the Setup Guide above, please complete the following steps:
    * [ ] Setup password-less ssh connections from `carpica`, `kobol` and `admin-pi`
        * [ ] `ssh-copy-id sebastian@runner-04-pi.fritz.box`

### `runner-05-pi.fritz.box`

* **Setup**: In addition to the tasks listed in the Setup Guide above, please complete the following steps:
    * [ ] Setup password-less ssh connections from `carpica`, `kobol` and `admin-pi`
        * [ ] `ssh-copy-id sebastian@runner-05-pi.fritz.box`

### `runner-06-pi5.fritz.box`

* **Setup**: In addition to the tasks listed in the Setup Guide above, please complete the following steps:
    * [ ] Setup password-less ssh connections from `carpica`, `kobol` and `admin-pi`
        * [ ] `ssh-copy-id <sebastian@runner-06-pi5.fritz.box>
