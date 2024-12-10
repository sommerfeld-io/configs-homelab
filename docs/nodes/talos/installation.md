# Talos Cluster - Installation

The installation of the Talos Kubernetes Cluster is done in multiple steps. The first step is to install the `talos-mgmt-pi` node. This node is used to manage the Talos Kubernetes Cluster. The `talos-mgmt-pi` node is installed and provisioned by Ansible.

The second step is to install the actual Talos nodes. These nodes are Raspberry Pi devices running Talos Linux. The nodes are not provisioned by Ansible. They run the Talos variant for Raspberry Pi directly.

## Install Management Node

- [ ] Install Operating System [Ubuntu Server](https://ubuntu.com) via the [Raspberry Pi Imager](https://www.raspberrypi.com/software)
- [ ] Enable password-less SSH connections (from workstation, not the RasPi node)
    - [ ] `ssh sebastian@talos-mgmt-pi.fritz.box`
    - [ ] `ssh-copy-id sebastian@talos-mgmt-pi.fritz.box`
- [ ] Run the Ansible Playbook `raspi-talos.yml` to install all necessary tools and configurations. This playbook generates the Talos configuration files - on the management node as well as the for the Talos Kubernetes nodes. See playbook `components/ansible/playbooks/raspi-talos.yml` for more details.

The Ansible Playbook `raspi-talos.yml` (among others) installs and starts Node Exporter as `systemd` service. The Node Exporter can be reached at <http://talos-mgmt-pi.fritz.box:9100>.

The Management Pi also runs all necessary tools like `kubectl` and `talosctl` to manage the Talos Kubernetes Cluster.

## Install Talos Kubernetes Nodes

- [ ] Make sure you did run the Ansible Playbook `raspi-talos.yml` to install all necessary tools and configurations. This playbook generates the Talos configuration files - on the management node (as stated above) as well as the for the Talos Kubernetes nodes.
- [ ] Follow the instructions from the [Talos Documentation for the Raspberry Pi Series](https://www.talos.dev/v1.8/talos-guides/install/single-board-computers/rpi_generic) to install Talos on the Raspberry Pi devices.
    - [ ] Copy the generated Talos configuration file for the respective node from `components/talos-raspi-cluster/node-configs` to the SD card before booting the node. This allows for an unattended installation without having to manually configure the node through a setup wizard. See playbook `components/ansible/playbooks/raspi-talos.yml` for more details.

!!! note Recommendation
    Flash the SD card with Balena Etcher. The tool is installed through the ansible playbook `ubuntu-desktop-baseline.yml`.
