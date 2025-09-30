# Raspberry Pi - Fleet Overview

The Raspberry Pi fleet consists of multiple Raspberry Pi devices that serve as lightweight nodes in the home lab infrastructure. These devices handle dedicated roles including administrative tasks, monitoring and logging aggregation, and testing environments. Each Pi is configured through automated Ansible playbooks to ensure consistent deployment and management across the entire fleet.

## Context

The home lab infrastructure consists of Ubuntu workstations, complemented by a fleet of Raspberry Pi nodes that handle specialized workloads.

```kroki-c4plantuml
@startuml
!include C4_Context.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_LEFT_RIGHT()

Person(user, "User", "A person using a computer or mobile device")

System(raspi, "Raspberry Pi", "Raspberry Pi devices used for various tasks")

System_Ext(workstation, "Ubuntu Workstations", "Workstations and laptops used for everyday work")

Rel(user, raspi, "Uses")
Rel(user, workstation, "Uses")

@enduml
```

## Containers

The Raspberry Pi fleet consists of multiple Raspberry Pi devices that serve as lightweight nodes in the home lab infrastructure. These devices handle dedicated roles including administrative tasks, monitoring and logging aggregation, and testing environments.

```kroki-c4plantuml
@startuml
!include C4_Container.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

LAYOUT_TOP_DOWN()

Person(user, "User", "A person using a computer or mobile device")

System_Boundary(api, "admin-pi") {
    Container(telemetry, "Telemetry", "Docker Compose Stack", "Monitoring and Logging Stack with Prometheus, Grafana and Loki")

    Container(awx, "AWX", "Docker Compose Stack", "Run playbooks for automated tests of Compose Stacks etc.")

    Container_Ext(ansible, "Ansible", "CLI", "Run playbooks as a fallback for caprica and kobold nodes")
}

System_Boundary(tr01pi, "testrunner-01-pi") {
    Container(sut, "System under Test", "Docker Compose Stack", "Various apps to be started and tested from our GitHub repositories")
}

Container_Ext(all, "All Hosts", "Workstation and RasPi", "All machines and workstations in the home lab")

Rel(user, api, "Uses")
Rel(awx, sut, "Control and test")
Rel(ansible, all, "Provision and configure")
Rel(all, telemetry, "Send logs and metrics")

@enduml
```
