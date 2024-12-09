# Raspberry Pi - Talos Cluster

[Talos Linux](https://www.talos.dev) is Linux designed for Kubernetes - secure, immutable, and minimal.

## Overview

The Talos Kubernetes cluster in my homelab is powered by a small fleet of Raspberry Pi devices. This setup combines the minimalism and security of Talos Linux with the versatility of Raspberry Pi, creating a lightweight, efficient, and manageable Kubernetes environment.

By leveraging this cluster, I can experiment with Kubernetes deployments and maintain a dedicated, small-scale infrastructure for development and testing purposes.

This also provides a platform for some production-grade applications and services running in my homelab.

### Context

```kroki-c4plantuml
@startuml
!include C4_Context.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_TOP_DOWN()

Person(user, "User", "A person using a computer or mobile device")

System_Ext(router, "FritzBox Router", "The homelab router which provides network communication, internet access, DNS, DHCP, ...")

System_Ext(workstation, "Ubuntu Workstations", "Workstations and laptops used for everyday work\n\nTraditional computers")

System(switch, "Network Switch", "Allow cable connections for the Kubernetes cluster")

System(talos, "Talos k8s Cluster", "Raspberry Pi Cluster running Talos Linux")

System(mgmt, "Talos Mgmt Node", "Raspberry Pi Cluster running Talos Linux")

Rel_Neighbor(user, workstation, "Uses")
Rel(router, workstation, "Network access", "DNS, DHCP")
Rel(router, switch, "Network access", "DNS, DHCP")
Rel(switch, talos, "Network access", "DNS, DHCP")
Rel(router, mgmt, "Network access", "DNS, DHCP")
Rel(workstation, talos, "Manage", "talosctl")
Rel_Neighbor(workstation, mgmt, "Manage", "SSH")
@enduml
```

The Talos Raspberry Pi nodes should get their IP addresses from the router via DHCP. However, the router should always provide the same IP addresses to each nodes.

### Containers

The `talos-mgmt-pi` setup is done by Ansible. The Ansible Playbook are run from one of the `Ubuntu Workstations`.

The actual Talos Raspberry Pi Nodes are not provisioned by Ansible. They run the Talos Variant for Raspberry Pi directly.

- Raspberry Pi 3A+: 32GB SD Card and 2GB RAM.
- Raspberry Pi 4: 32GB SD Card and 8GB RAM.

```kroki-c4plantuml
@startuml
!include C4_Container.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_TOP_DOWN()

Person(user, "User", "A person using a computer or mobile device")

System_Ext(workstation, "Ubuntu Workstations", "Workstations and laptops used for everyday work\n\nTraditional computers")

Container(mgmt, "talos-mgmt-pi", "Raspberry Pi 3A+", "Management Node for Kubernetes providing tools (kubectl, talosctl, ...)")

System_Boundary(talos, "Talos Kubernetes Cluster") {
    Container(cp, "talos-control-pi", "Raspberry Pi 4", "Control Plane Node for Kubernetes")
    Container(w1, "talos-worker-pi-1", "Raspberry Pi 4", "Worker Node for applications and services")
    Container(w2, "talos-worker-pi-2", "Raspberry Pi 4", "Worker Node for applications and services")
}

Rel(user, workstation, "Uses")
Rel(workstation, mgmt, "Connect", "SSH")
Rel_Neighbor(mgmt, talos, "Manage", "talosctl\nkubectl")
Rel(cp, w1, "Manage")
Rel(cp, w2, "Manage")

@enduml
```

The setup features a `talos-mgmt-pi` to avoid conflicts with other tool installations on the `Ubuntu Workstations`. The `Ubuntu Workstations` are used for everyday work, proof of concepts, and development. So there might run other Kuberenetes variants like `minikube`. By establishing a dedicated `talos-mgmt-pi` we avoid possible conflicts with e.g. `kubectl`.

### Components

To deploy applications and services to the Talos Kubernetes Cluster, we use ArgoCD. ArgoCD is a GitOps tool that helps to manage all deployments, applications, and services in a GitOps way. Applications and services are **never directly deployed to the cluster (e.g. through `kubectl`). Everything is managed by ArgoCD.

```kroki-c4plantuml
@startuml
!include C4_Component.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_TOP_DOWN()

ContainerDb(repo, "Repository", "Github", "Configuration and Manifest files (for ArgoCD)")

System_Boundary(talos, "Talos Kubernetes Cluster") {
    Component(argo, "ArgoCD", "Base Component", "Manage all deployments, applications, and services in a GitOps way")

    Component(node_exporter, "Node Exporter", "Base Component", "Metrics for Monitoring")
    Component(prometheus, "Prometheus", "Base Component", "Monitoring Application")
    Component(grafana, "Grafana", "Base Component", "Monitoring Application")
    Component(etc, "etc", "Base Component", "Possible other applications")
}

Rel(repo, argo, "Observed by ArgoCD")
Rel(argo, node_exporter, "Deploy", "sync")
Rel(argo, prometheus, "Deploy", "sync")
Rel(argo, grafana, "Deploy", "sync")
Rel(argo, etc, "Deploy", "sync")

@enduml
```

ArgoCD is set up with the help of the ArgoCD Autopilot. The Autopilot is a CLI tool that helps to set up ArgoCD with the best practices. It sets up all configurations and manifests inside a repository. The manifests are part of [this repository](https://github.com/sommerfeld-io/configs-homelab).

Applications are organized in namespaces. The `Base Component` applications are inside a dedicated namespace. Applications are inside their own namespaces.

### Code / Configuration

According to our [Development Guide](about/development-guide.md), all code and configuration are stored in a Git repository. We treat everything as code.

Information about the replica count, resources, possible assignments to nodes, and other (kubernetes-related) configurations are part of the manifests config files.

### Network Setup

All RasPi nodes that are running the Talos Cluster are connected to the switch via cable. The switch is connected to the wifi network through the repeater.

Requests from workstations and the management node are routed through the router to the RasPi nodes, so they still rely on WiFi. But the cluster nodes themselves should communicate with each other through the wired connection. For internet access, they too rely on the WiFi connection.

```kroki-plantuml
@startuml

skinparam linetype polyline
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

component ws as "Workstation"
component Router
component Repeater
component Switch
component pi_mgmt as "talos-mgmt-pi" <<RasPi Node>>
component pi0 as "talos-control-pi" <<RasPi Node>>
component pi1 as "talos-worker-pi-1" <<RasPi Node>>
component pi2 as "talos-worker-pi-2" <<RasPi Node>>

ws -down-> Router
Router -right-> Repeater
Router -down-> pi_mgmt
Repeater -right-> Switch
Switch -down-> pi0
Switch -down-> pi1
Switch -down-> pi2

@enduml
```

## Installation

The installation of the Talos Kubernetes Cluster is done in multiple steps. The first step is to install the `talos-mgmt-pi` node. This node is used to manage the Talos Kubernetes Cluster. The `talos-mgmt-pi` node is installed and provisioned by Ansible.

The second step is to install the actual Talos nodes. These nodes are Raspberry Pi devices running Talos Linux. The nodes are not provisioned by Ansible. They run the Talos variant for Raspberry Pi directly.

### Install Management Node

- [ ] Install Operating System [Ubuntu Server](https://ubuntu.com) via the [Raspberry Pi Imager](https://www.raspberrypi.com/software)
- [ ] Enable password-less SSH connections (from workstation, not the RasPi node)
    - [ ] `ssh sebastian@talos-mgmt-pi.fritz.box`
    - [ ] `ssh-copy-id sebastian@talos-mgmt-pi.fritz.box`
- [ ] Run the Ansible Playbook `raspi-talos.yml` to install all necessary tools and configurations. This playbook generates the Talos configuration files - on the management node as well as the for the Talos Kubernetes nodes. See playbook `components/ansible/playbooks/raspi-talos.yml` for more details.

The Ansible Playbook `raspi-talos.yml` (among others) installs and starts Node Exporter as `systemd` service. The Node Exporter can be reached at <http://talos-mgmt-pi.fritz.box:9100>.

The Management Pi also runs all necessary tools like `kubectl` and `talosctl` to manage the Talos Kubernetes Cluster.

### Install Talos Nodes

- [ ] Make sure you did run the Ansible Playbook `raspi-talos.yml` to install all necessary tools and configurations. This playbook generates the Talos configuration files - on the management node (as stated above) as well as the for the Talos Kubernetes nodes.
- [ ] Follow the instructions from the [Talos Documentation for the Raspberry Pi Series](https://www.talos.dev/v1.8/talos-guides/install/single-board-computers/rpi_generic) to install Talos on the Raspberry Pi devices.
    - [ ] Copy the generated Talos configuration file for the respective node from `components/talos-raspi-cluster/node-configs` to the SD card before booting the node. This allows for an unattended installation without having to manually configure the node through a setup wizard. See playbook `components/ansible/playbooks/raspi-talos.yml` for more details.

## References / External Links

- Initial Setup of the Talos cluster took place with issue [#19 Setting Up a 3-Node Talos Kubernetes Cluster in my Personal Homelab](https://github.com/sommerfeld-io/configs-homelab/issues/19) and Pull Request [#24 Talos Kubernetes on Raspberry Pi cluster](https://github.com/sommerfeld-io/configs-homelab/pull/24).
