# Raspberry Pi Nodes

The Raspberry Pi fleet consists of multiple Raspberry Pi devices that serve as lightweight nodes in the home lab infrastructure. These devices handle dedicated roles including administrative tasks, monitoring and logging aggregation, and testing environments.

## RasPi Fleet Overview

The Raspberry Pi fleet consists of multiple Raspberry Pi devices that handle dedicated roles. Each Pi is configured through automated Ansible playbooks to ensure consistent deployment and management across the entire fleet. No Pi has password-less SSH connections configured so they cannot easily connect to any other node.

| Name        | Model    | RAM | Main Storage  | Role                    |
|-------------|----------|-----|---------------|-------------------------|
| `raspi4-01` | RasPi 4B | 8GB | 32GB microSD  | Secondary OpenClaw Node |
| `raspi4-02` | RasPi 4B | 8GB | 32GB microSD  | -                       |
| `raspi4-03` | RasPi 4B | 8GB | 128GB microSD | -                       |
| `raspi5-01` | RasPi 5  | 8GB | 32GB microSD  | Main OpenClaw Node      |

Workstations and Raspberry Pi nodes are organized in a DeskPi RackMate T0, a compact 10-inch rack system. This setup keeps all devices securely mounted and easily accessible.

```ditaa
+-------------+      +-------------+-------------+      +-------------+
|  SSD 120GB  +------+  raspi4-01  |  raspi4-02  +------+  SSD 240GB  |
+-------------+      +----------------+----------+      +-------------+
                     |  raspi5-01  |  raspi4-03  |
                     +-----------------+---------+
                     |  Power                    |
                     +---------------------------+
                     |  -                        |
                     +---------------------------+
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
    * [ ] [Playbook "raspi"](../../ansible/playbooks/raspi.md)
    * [ ] Allow the machine to interact with GitHub. Use public key `id_rsa.pub`, NOT the private key!
    * [ ] Login to Docker registry on the new machine: `docker login`
    * [ ] [Playbook "repositories"](../../ansible/playbooks/repositories.md)
    * [ ] [Playbook "grafana-agents"](../../ansible/playbooks/grafana.md)

### Follow-Up Todos

* [ ] Add the new RasPi Node to `ansible/playbooks/assets/global-taskfile.yml` for easy SSH connections.
* [ ] Setup password-less ssh connections from `picon` and `kobol` to the RasPi node
    * [ ] `ssh-copy-id sebastian@<NODE_NAME>.fritz.box`
