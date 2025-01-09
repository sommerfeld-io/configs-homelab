# Talos Cluster - Monitoring + Logging

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

## Monitoring

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

```kroki-c4plantuml
@startuml
!include C4_Component.puml

skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

skinparam NoteFontColor #E2E4E9
skinparam NoteBorderColor #E2E4E9
skinparam NoteBackgroundColor #1E2129

LAYOUT_LEFT_RIGHT()

Component(grafana, "Grafana Cloud", "SaaS", "Monitoring Solution as a Service")

System_Boundary(talos, "Talos Kubernetes Cluster") {
    Component(node_exporter, "Node Exporter", "Base Component", "Metrics for Monitoring")
}

Rel(grafana, node_exporter, "Consume", "HTTPS")

note top of node_exporter: Running on all worker nodes and control plane

@enduml
```

- [Node Exporter on `talos-w1.fritz.box`](http://talos-cp.fritz.box:30091)
- [Node Exporter on `talos-w1.fritz.box`](http://talos-w1.fritz.box:30091)
- [Node Exporter on `talos-w2.fritz.box`](http://talos-w2.fritz.box:30091)
- [Node Exporter on `talos-w3.fritz.box`](http://talos-w3.fritz.box:30091)

!!! warning "TODO"
    - Diagram with all components

## Logging

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

!!! warning "TODO"
    - Diagram with all components
