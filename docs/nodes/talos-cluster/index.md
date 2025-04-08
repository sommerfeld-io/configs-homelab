# Talos Cluster - Overview

The [Talos Kubernetes](https://www.talos.dev) cluster in my homelab is powered by a small fleet of Raspberry Pi devices. This setup combines the minimalism and security of Talos Linux with the versatility of Raspberry Pi, creating a lightweight, efficient, and manageable Kubernetes environment.

[Talos Linux](https://www.talos.dev) is Linux designed for Kubernetes - secure, immutable, and minimal.

By leveraging this cluster, I can experiment with Kubernetes deployments and maintain a dedicated, small-scale infrastructure for development and testing purposes.

This also provides a platform for some production-grade applications and services running in my homelab.

## Context

```kroki-c4plantuml
@startuml
!include C4_Context.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_LEFT_RIGHT()

Person(user, "User", "A person using a computer or mobile device")

System_Ext(workstation, "Ubuntu Workstations", "Workstations and laptops used for everyday work\n\nTraditional computers")

System(talos, "Talos Kubernetes", "Raspberry Pi Cluster running Talos Linux")

Rel(user, workstation, "Uses")
Rel(workstation, talos, "Access", "talosctl\nkubectl")
@enduml
```

## Containers

The Talos Raspberry Pi Nodes are not provisioned by Ansible. They run the Talos variant for Raspberry Pi directly.

- Raspberry Pi 4: 8 GB RAM and 32 GB SD-Card
- Raspberry Pi 5: 8 GB RAM, Quad Core 2,4GHz and 128 GB SD-Card

Since Talos Linux is designed to be immutable and secure, there is no way and no need to provision the nodes with Ansible. Talos Linux is managed entirely through an API with `talosctl`. So the Talos nodes are treated as some sort of appliance.

```kroki-c4plantuml
@startuml
!include C4_Container.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_TOP_DOWN()

Person(user, "User", "A person using a computer or mobile device")

System_Ext(workstation, "Ubuntu Workstations", "Workstations and laptops used for everyday work\n\nTraditional computers")

Container(mgmt, "Admin VM", "Vagrantbox", "Management Node for Kubernetes providing tools (kubectl, talosctl, ...)")

System_Boundary(talos, "Talos Kubernetes Cluster") {
    Container(cp, "talos-cp", "RaspPi Model 4", "Control Plane Node for Kubernetes")
    Container(w1, "talos-w1", "RaspPi Model 4", "Worker Node for applications and services")
    Container(w2, "talos-w2", "RaspPi Model 4", "Worker Node for applications and services")
    Container(w3, "talos-w3", "RaspPi Model 4", "Worker Node for applications and services")
    Container(w4, "talos-w4", "RaspPi Model 5", "Worker Node for applications and services")
}

Rel(user, workstation, "Uses")
Rel(workstation, mgmt, "Connect", "SSH")
Rel_Neighbor(mgmt, talos, "Manage", "talosctl\nkubectl")
Rel(cp, w1, "Manage")
Rel(cp, w2, "Manage")
Rel(cp, w3, "Manage")
Rel(cp, w4, "Manage")

@enduml
```

The setup features an Admin VM to avoid conflicts with other tool installations on the `Ubuntu Workstations`. The `Ubuntu Workstations` are used for everyday work, proof of concepts, and development. So there might run other Kuberenetes variants like `minikube`. By establishing a dedicated Admin VM we avoid possible conflicts with e.g. `kubectl`.

!!! note "Stateless Cluster"
    The whole cluster is intended to be stateless. This means that no data is stored on any of the nodes. The only storage is the SD-Card which is used for the Talos OS itself. There are no external storage solutions.

## Components

To deploy applications and services to the Talos Kubernetes Cluster, we use [ArgoCD](https://argo-cd.readthedocs.io/en/stable). ArgoCD is a GitOps tool that helps to manage all deployments, applications, and services in a GitOps way. Applications and services are **never directly deployed to the cluster (e.g. through `kubectl`). Everything is managed by ArgoCD.

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

    Component(node_exporter, "Node Exporter", "Application", "Metrics for Monitoring")
    Component(etc1, "etc", "Application", "Some other application")
    Component(etc2, "etc", "Application", "Some other application")
    Component(etc3, "etc", "Application", "Some other application")
}

Rel(repo, argo, "Observed by ArgoCD")
Rel(argo, node_exporter, "Deploy", "sync")
Rel(argo, etc1, "Deploy", "sync")
Rel(argo, etc2, "Deploy", "sync")
Rel(argo, etc3, "Deploy", "sync")

@enduml
```

[ArgoCD](https://argo-cd.readthedocs.io/en/stable) is set up with the help of the [ArgoCD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable). The Autopilot is a CLI tool that helps to set up ArgoCD with the best practices. It sets up all configurations and manifests inside a repository. The manifests are part of [this repository](https://github.com/sommerfeld-io/configs-homelab).

Applications are organized in namespaces. The `Base Component` applications are inside a dedicated namespace. Applications are inside their own namespaces.

## Code / Configuration

According to our [Development Guide](https://github.com/sommerfeld-io/.github/blob/main/docs/development-guide.md), all code and configuration are stored in a Git repository. We treat everything as code.

Information about the replica count, resources, possible assignments to nodes, and other (kubernetes-related) configurations are part of the manifests config files.

## Network Setup

All RasPi nodes that are running the Talos Cluster are connected to the switch via cable. The switch is connected to the wifi network through the repeater.

Requests from workstations and the management node are routed through the router to the RasPi nodes, so they still rely on WiFi. But the cluster nodes themselves should communicate with each other through the wired connection. For internet access, they too rely on the WiFi connection.

```kroki-plantuml
@startuml

skinparam linetype polyline
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9
skinparam ArrowFontColor #E2E4E9

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

component Router
component Repeater
component Switch

Router -right-> Repeater: Wifi
Repeater -right-> Switch: Ethernet

@enduml
```

```kroki-plantuml
@startuml

skinparam backgroundColor transparent
skinparam arrowColor #E2E4E9


nwdiag {
  group switch_cable {
    color = "#999";
    description = "Switch\nEthernet";
    cp;
    w1;
    w2;
    w4;
  }

  group router_cable {
    color = "#999";
    description = "Router\nEthernet";
    w3;
  }

  internet [shape = cloud];
  internet -- router;

  network fritz.box {
      address = "192.168.178.x/24"

      router;

      cp [description = "talos-cp"];
      w1 [description = "talos-w1"];
      w2 [description = "talos-w2"];
      w4 [description = "talos-w4"];

      w3 [description = "talos-w3"];
  }
}
@enduml
```

The Talos Raspberry Pi nodes should get their IP addresses from the router via DHCP. The router should assign the same IP address to the same device every time. This is not mandatory but recommended.

## RasPi Rack Setup

The nodes are sorted in the rack as follows (top to bottom):

```kroki-rackdiag
rackdiag {
  4U;
  4: talos-cp\nRasPi 4;
  3: talos-w1\nRasPi 4;
  2: talos-w2\nRasPi 4;
  1: talos-w4\nRasPi 5;
}
```

```kroki-rackdiag
rackdiag {
  1U;
  1: talos-w3\nRasPi 4;
}
```

## References / External Links

- Initial Setup of the Talos cluster took place with issue [#19 Setting Up a 3-Node Talos Kubernetes Cluster in my Personal Homelab](https://github.com/sommerfeld-io/configs-homelab/issues/19) and Pull Request [#24 Talos Kubernetes on Raspberry Pi cluster](https://github.com/sommerfeld-io/configs-homelab/pull/24).
