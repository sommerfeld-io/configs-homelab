# Talos Cluster - Monitoring + Logging

In this document, we will explore the monitoring and logging setup for the Talos Kubernetes Cluster. Monitoring and logging are crucial aspects of managing and maintaining a healthy and performant cluster. By implementing effective monitoring and logging solutions, we can gain insights into the cluster's performance and (hopefully) detect possible issues.

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

Component(prometheus, "Prometheus", "admin-pi", "On-Premise Monitoring Stack")
Component(grafana, "Grafana", "admin-pi", "On-Premise Monitoring Stack")

System_Boundary(talos, "Talos Kubernetes Cluster") {
    Component(node_exporter, "Node Exporter", "Base Component", "Metrics for Monitoring")
}

Rel(node_exporter, prometheus, "HTTP")
Rel_Neighbor(prometheus, grafana, "HTTP")

note right of talos: Running on all worker nodes and control plane

@enduml
```

To start and stop the Monitoring and Logging stack, run `~/docker-stacks-cli.sh` on the `admin-pi.fritz.box`.

- [Grafana Web-Interface on `admin-pi.fritz.box`](http://admin-pi.fritz.box)
- For more information about the monitoring stack itself, see [Docker Stack - Monitoring and Logging](../../api-docs/docker/monitoring-logging.md).

## Monitoring

Each node in the Talos Kubernetes Cluster runs a `node_exporter` instance. The `node_exporter` is a Prometheus exporter for hardware and OS metrics. It exposes a wide variety of metrics, including CPU, memory, disk, and network usage.

- [Node Exporter on `talos-cp.fritz.box`](http://talos-cp.fritz.box:30091)
- [Node Exporter on `talos-w1.fritz.box`](http://talos-w1.fritz.box:30091)
- [Node Exporter on `talos-w2.fritz.box`](http://talos-w2.fritz.box:30091)
- [Node Exporter on `talos-w3.fritz.box`](http://talos-w3.fritz.box:30091)

<!-- ## Logging

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. -->

## References / External Links

- For details on why we set up a dedicated monitoring stack on the `admin-pi`, see [ADR-002 - Talos RasPi: Prometheus and Grafana inside Kubernetes vs outside on the admin-pi vs Grafana Cloud](https://github.com/sommerfeld-io/configs-homelab/issues/35) on GitHub.
