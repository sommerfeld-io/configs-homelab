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

## Install Cluster with Control Plane and Worker Nodes

These steps only need to be done once when the initial setup is done or when the cluster is re-installed from scratch. The steps are not necessary when the cluster is already running and a new node is added.

??? note "Re-use of existing configurations"
    Installing a new cluster should also be possible by re-using the existing configurations for the management node and and the talos cluster nodes.

- [ ] Make sure you generated the Talos configuration on the `talos-mgmt-pi` node. Only needs to be done once.
    - [ ] `talosctl gen config talos-pi-cluster https://talos-control-pi.fritz.box:6443`
    - [ ] `cp talosconfig ~/.talos/config`
    - [ ] Download the config files to this repo into `components/talos-raspi-cluster/node-configs`, cleanup the yaml markup, duplicate the worker yaml file for each worker node and adjust the hostnames in all yaml files as described in <https://www.talos.dev/v1.8/reference/configuration/v1alpha1/config/#Config.machine.network>.

These steps need to be done for each Raspberry Pi node that should join the Talos Kubernetes cluster.

- [ ] Download the Talos image via curl `-LO <https://factory.talos.dev/image/ee21ef4a5ef808a9b7484cc0dda0f25075021691c8c09a276591eedb638ea1f9/v1.8.0/metal-arm64.raw.xz>` and extract the image with `xz -d metal-arm64.raw.xz`.
- [ ] Flash the SD card with "Disks" application which is shipped with Ubuntu. You should remove all partitions from the SD card. Then Choose "Restore Disk Image" from the menu in the and select the Talos image.
- [ ] Create a new node configuration for the new node - typically a new `talos-worker-pi-<COUNTER>.yml` file.
    - [ ] Update the hostname inside the config file.
    - [ ] Make sure these changes are available omn the `talos-mgmt-pi` node - typically by pushing the changes to the repository.

Once the SD card is flashed and inserted into the Raspberry Pi and boot. Check the FritzBox Router and Repeater settings for the new device.

- [ ] Assign a name to the device. This should be the same as the hostname of the RasPi node itself.
- [ ] Also ensure that the device always gets the same IP address (not mandatory but recommended).

Continue with configuring the Talos node. Do this from the `talos-mgmt-pi` node.

- [ ] On the RasPi node, switch into the `configs-homelab` repo and the into the folder `components/talos-raspi-cluster/node-configs`.
- [ ] Apply configs from this repo to the **control plane**:
    - [ ] `talosctl apply-config --insecure --nodes talos-control-pi.fritz.box --file talos-control-pi.yml`
- [ ] Apply configs from this repo to each **worker node**:
    - [ ] `talosctl apply-config --insecure --nodes talos-worker-pi-<COUNTER>.fritz.box --file talos-worker-pi-<COUNTER>.yml` - Remember to replace both `<COUNTER>` places with the actual number of the worker node.
- [ ] Bootstrapping your Kubernetes cluster with Talos is as simple as calling `talosctl bootstrap --nodes talos-control-pi.fritz.box --endpoints talos-control-pi.fritz.box` from the users home directory.
- [ ] On the `talos-mgmt-pi` node run `talosctl kubeconfig` to allow `kubectl` to connect to the Talos Kubernetes Cluster.

## Setup ArgoCD

!!! warning TODO
    This section is not yet implemented. Write some words in ArgoCD and ArgoCD Autopilot ...

## References / External Links

- Talos Documentation on [Talos Documentation for the Raspberry Pi Series](https://www.talos.dev/v1.8/talos-guides/install/single-board-computers/rpi_generic) with (amont others) instructions on "Installing Talos on Raspberry Pi SBC’s using raw disk image".
- After the Talos image was written to the SD card, the [Getting started &raquo; Modifying the Machine configs](https://www.talos.dev/v1.8/introduction/getting-started/#modifying-the-machine-configs) were followed. However, the install instructions above cover the necessary steps, the this link is listed purely for informational purposes.
