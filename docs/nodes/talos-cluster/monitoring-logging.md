# Talos Cluster - Monitoring + Logging

In this document, we will explore the monitoring and logging setup for the Talos Kubernetes Cluster. Monitoring and logging are crucial aspects of managing and maintaining a healthy and performant cluster. By implementing effective monitoring and logging solutions, we can gain insights into the cluster's performance and (hopefully) detect possible issues.

To start and stop the Monitoring and Logging stack, run `~/docker-stacks-cli.sh` on the `admin-pi.fritz.box`.

- [Grafana Web-Interface on `admin-pi.fritz.box`](http://admin-pi.fritz.box)
- For more information about the monitoring stack itself, see [Docker Stack - Monitoring and Logging](../../api-docs/docker/monitoring-logging.md).

## Monitoring

```kroki-c4plantuml
@startuml
!include C4_Component.puml

' skinparam linetype ortho
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9

skinparam NoteFontColor #E2E4E9
skinparam NoteBorderColor #E2E4E9
skinparam NoteBackgroundColor #1E2129

LAYOUT_LEFT_RIGHT()

Component_Ext(prometheus, "Prometheus", "admin-pi", "On-Premise Monitoring Stack")
Component_Ext(grafana, "Grafana", "admin-pi", "On-Premise Monitoring Stack")

System_Boundary(talos, "Talos Kubernetes Cluster") {
    Component(node_exporter, "Node Exporter", "Application", "System metrics like CPU, Memory, Disk, Network")
    Component(argo_metrics, "ArgoCD Metrics", "Endpoint", "Default Metrics Endpoints from ArgoCD")
    Component(argo_service, "ArgoCD Metrics Services", "Services", "Expose as NodePort")
    Component(metrics_server, "metrics-server", "Service", "Shipped with the Kubernetes Dashboard")
    Component(kube_dashboard, "k8s-dashboard", "Application", "Web Interface")
}

Rel(node_exporter, prometheus, "HTTP")
Rel(argo_metrics, argo_service, "HTTP")
Rel(argo_service, prometheus, "HTTP")
Rel(metrics_server, prometheus, "HTTP")
Rel(metrics_server, kube_dashboard, "HTTP")

Rel_Neighbor(prometheus, grafana, "HTTP")

note right of talos: Running on all worker nodes and the control plane node

@enduml
```

### System Metrics (Node Exporter)

Each node in the Talos Kubernetes Cluster runs a `node_exporter` instance. The `node_exporter` is a Prometheus exporter for hardware and OS metrics. It exposes a wide variety of metrics, including CPU, memory, disk, and network usage.

- <http://talos-cp.fritz.box:30091>
- <http://talos-w1.fritz.box:30091>
- <http://talos-w2.fritz.box:30091>
- <http://talos-w3.fritz.box:30091>

<!-- ### Kubernetes Metrics

[`kube-state-metrics`](https://github.com/kubernetes/kube-state-metrics) provides Kubernetes resource-level metrics, such as pod counts, namespace counts, and pod distribution.

- <http://talos-cp.fritz.box:30090> -->

### ArgoCD Metrics

Argo CD exposes different sets of Prometheus metrics per server. The "Application Controller Metrics" about applications can be scraped at the `argocd-metrics:8082/metrics` endpoint.

The default metrics services from ArgoCD are not accessible from outside the cluster. To expose them, we have set up our own services that basically are a copy of the default services but as a NodePort service.

- **Application Controller Metrics**
    - The Application Controller in ArgoCD is responsible for managing and reconciling the desired state of applications.
    - Custom service `components/talos-cluster/manifests/apps/monitoring-logging/argocd-metrics.yaml` based on the `argocd-metrics` from the `argo-cd` application (as seen in the ArgoCD UI)
    - <http://talos-cp.fritz.box:30092/metrics>
- **ArgoCD Server**
    - The ArgoCD Server is the core component that provides the web-based user interface and API for managing applications and GitOps workflows.
        - Custom service `components/talos-cluster/manifests/apps/monitoring-logging/argocd-server-metrics.yaml` based on the `argocd-server-metrics` from the `argo-cd` application (as seen in the ArgoCD UI)
    - <http://talos-cp.fritz.box:30093/metrics>
- **Repo Server**
    - The Repo Server in ArgoCD is responsible for interacting with Git repositories to fetch application manifests and sync application states.
        - Custom service `components/talos-cluster/manifests/apps/monitoring-logging/argocd-repo-server-metrics.yaml` based on the `argocd-repo-server` from the `argo-cd` application (as seen in the ArgoCD UI)
    - <http://talos-cp.fritz.box:30094/metrics>

Prometheus scrapes these endpoints to collect metrics and Grafana visualizes them though the example dashboard provided by ArgoCD. The example dashboard is linked in the [Dashboard section on the official Metrics Docs page](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/#dashboards).

??? note "Namespace for custom services to expose ArgoCD metrics"
    Even though our own monitoring and logging deployments are inside the `monitoring-logging` namespace, the custom services to expose ArgoCD metrics must be in the `argocd` namespace.

### Kubernetes Dashboard

The Kubernetes Dashboard is a general-purpose, web-based UI for Kubernetes clusters. It allows users to manage applications running in the cluster and troubleshoot them, as well as manage the cluster itself.

The Kubernetes Dashboard is not accessible from outside the cluster. To expose it, we have set up our own service as a NodePort service. Addtionally we expose the metrics-server, which is shipped with the dashboard as a NodePort service as well.

- <http://talos-cp.fritz.box:30001>
- <http://talos-cp.fritz.box:30002>

<!-- ## Logging

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. -->

## References / External Links

- For details on why we set up a dedicated monitoring stack on the `admin-pi`, see [ADR-002 - Talos RasPi: Prometheus and Grafana inside Kubernetes vs outside on the admin-pi vs Grafana Cloud](https://github.com/sommerfeld-io/configs-homelab/issues/35) on GitHub.
- ArgoCD Metrics
    - Official docs about [Argo CD exposing different sets of Prometheus metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics)
    - Blog post about [Enabling ArgoCD metrics and Monitoring Using Kube-Prometheus-Stack](https://medium.com/@randeniyamalitha08/enabling-argocd-metrics-and-monitoring-using-kube-prometheus-stack-ebece18c41d8)