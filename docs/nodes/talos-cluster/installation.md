# Talos Cluster - Installation

The installation of the Talos Kubernetes Cluster is done in multiple steps. The first step is to install the `admin-pi` node. This node is used to manage the Talos Kubernetes Cluster. The `admin-pi` node is installed and provisioned by Ansible.

The second step is to install the actual Talos nodes. These nodes are Raspberry Pi devices running Talos Linux. The nodes are not provisioned by Ansible. They run the Talos variant for Raspberry Pi directly.

## Install Management Node

- [ ] Flash Operating System [Ubuntu Server](https://ubuntu.com) via the [Raspberry Pi Imager](https://www.raspberrypi.com/software) onto an SD card.
    - [ ] Configure the Raspberry Pi through the Raspberry Pi Imager to enable SSH, set a hostname and configure WiFi.
- [ ] Enable password-less SSH connections (from workstation, not the RasPi node)
    - [ ] `ssh sebastian@admin-pi.fritz.box`
    - [ ] `ssh-copy-id sebastian@admin-pi.fritz.box`
- [ ] Run the Ansible Playbook `raspi-talos.yml` to install all necessary tools and configurations. This playbook generates the Talos configuration files - on the management node as well as the for the Talos Kubernetes nodes. See playbook `components/ansible/playbooks/raspi-talos.yml` for more details.

The Ansible Playbook `raspi-talos.yml` (among others) installs and starts Node Exporter as `systemd` service. The Node Exporter can be reached at <http://admin-pi.fritz.box:9100>.

The Admin Pi also runs all necessary tools like `kubectl` and `talosctl` to manage the Talos Kubernetes Cluster.

## Install Cluster with Control Plane and Worker Nodes

The config files inside this repo are auto-generated and downloaded from the `admin-pi`. The `*-patch.yml` files however are manually created and are used to patch the Talos config files (meaning the are an input for generating the Talos config files).

### Setup SD Cards for Raspberry Pi Nodes

These steps need to be done for each Raspberry Pi node that should join the Talos Kubernetes cluster.

- [ ] Download the Talos image

    ```bash
    curl -LO https://factory.talos.dev/image/ee21ef4a5ef808a9b7484cc0dda0f25075021691c8c09a276591eedb638ea1f9/v1.8.0/metal-arm64.raw.xz
    ```

- [ ] Extract image

    ```bash
    xz -d metal-arm64.raw.xz
    ```

- [ ] Flash the SD card with "Disks" application which is shipped with Ubuntu. You should remove all partitions from the SD card. Then Choose "Restore Disk Image" from the menu in the and select the Talos image.
- [ ] Once the SD card is flashed and inserted into the Raspberry Pi and boot. Check the FritzBox Router and Repeater settings for the new device.
    - [ ] Assign a name to the device. This should be the same as the hostname of the RasPi node itself.
    - [ ] Also ensure that the device always gets the same IP address (not mandatory but recommended).

### Bootstrap the Talos Cluster

These steps only need to be done once when the initial setup is done or when the cluster is re-installed from scratch. The steps are not necessary when the cluster is already running and a new node is added.

??? note "Re-use of existing configurations"
    Installing a new cluster should also be possible with re-using the existing configurations for the management node and the talos cluster nodes. The cluster would need freshly flashed SD cards. But then the existing configurations can be re-used without having to generate new ones. Simply applying the configurations to the new nodes and bootstrapping the cluster should be sufficient.

- [ ] Make sure you generated the Talos configuration on the `admin-pi` node. Only needs to be done once. Run:

    ```bash
    # Run on admin-pi
    cd work/repos/sommerfeld-io/configs-homelab
    git pull

    cd components/talos-cluster/node-configs
    ./bootstrap-talos.sh
    ```

- [ ] Download config files from the `admin-pi`. Run:

    ```bash
    # Run on the host with the cloned repository
    cd work/repos/sommerfeld-io/configs-homelab
    cd components/talos-cluster/node-configs
    ./download-config.sh
    ```

- [ ] Push the configuration files to the remote repository

### Bootstrap ArgoCD

- [ ] Bootstrap ArgoCD on the `admin-pi` node. Only needs to be done once.

    ```bash
    # Run on admin-pi
    cd work/repos/sommerfeld-io/configs-homelab
    git pull

    cd components/talos-cluster/node-configs
    ./bootstrap-argocd.sh
    ```

    The `bootstrap-argocd.sh` installs ArgoCD with the help of the [ArgoCD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable/Getting-Started).

    !!! note "Personal Access Token"
        To bootstrap ArgoCD the script prompts for a Github personal access token to write the ArgoCD configuration to this repository. The token needs to have the `repo` scope. The token must be valid for as long as ArgoCD is used. This means that the token probably should never expire (unless you want to recover ArgoCD regularly with a new token).

    ??? note "Recover an ArgoCD Installation"
        In case the ArgoCD setup is broken, the `bootstrap-argocd.sh` script offers a recovery-option to re-install ArgoCD with all the configuration stored in the repository. So there is no need to re-configure everything manually or to backup the Talos Cluster (other than data that should explicitly be backed up). The cluster can be re-built from this configuration at any time.

## References / External Links

- Talos Documentation on [Talos Documentation for the Raspberry Pi Series](https://www.talos.dev/v1.8/talos-guides/install/single-board-computers/rpi_generic) with (amont others) instructions on "Installing Talos on Raspberry Pi SBC’s using raw disk image".
- After the Talos image was written to the SD card, the [Getting started &raquo; Modifying the Machine configs](https://www.talos.dev/v1.8/introduction/getting-started/#modifying-the-machine-configs) were followed. However, the install instructions above cover the necessary steps, the this link is listed purely for informational purposes.
