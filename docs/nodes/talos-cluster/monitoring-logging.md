# Talos Cluster - Monitoring + Logging

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

## Monitoring

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

```kroki-plantuml
@startuml

skinparam linetype ortho
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #3C72CE
skinparam ArrowFontColor #E2E4E9

skinparam FrameFontColor #E2E4E9
skinparam FrameBorderColor #E2E4E9
skinparam NodeBackgroundColor #e2e4e9

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

frame k8s as "Talos Cluster" <<Kubernetes>> {
    node cp as "Control Plane" <<Single Node>> {
        rectangle n_cp as "Node Exporter"
    }

    node w as "Worker Nodes" <<Multiple Nodes>> {
        rectangle w_cp as "Node Exporter"
    }

    cp -[hidden]down- w_cp
}

component g as "Grafana Cloud" <<SaaS>>

n_cp -right-> g
w_cp -right-> g

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
