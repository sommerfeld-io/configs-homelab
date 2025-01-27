# Talos Cluster - Monitoring + Logging

In this document, we will explore the monitoring and logging setup for the Talos Kubernetes Cluster. Monitoring and logging are crucial aspects of managing and maintaining a healthy and performant cluster. By implementing effective monitoring and logging solutions, we can gain insights into the cluster's performance and (hopefully) detect possible issues.

To start and stop the Monitoring and Logging stack, run `~/docker-stacks-cli.sh` on the `admin-pi.fritz.box`.

- [Grafana Web-Interface on `admin-pi.fritz.box`](http://admin-pi.fritz.box)
- For more information about the monitoring stack itself, see [Docker Stack - Monitoring and Logging](../../api-docs/docker/monitoring-logging.md).

## Monitoring

```kroki-plantuml
@startuml

skinparam linetype ortho
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9

skinparam arrowColor #E2E4E9
skinparam ArrowFontColor #E2E4E9

skinparam RectangleFontColor #ccc
skinparam RectangleBorderColor #85BBF0

skinparam NoteFontColor #E2E4E9
skinparam NoteBorderColor #E2E4E9
skinparam NoteBackgroundColor #1E2129

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

rectangle k8s as "Kubernetes Cluster" <<Talos>> {
    component node_exporter <<Metrics>> #85BBF0
    component argo as "ArgoCD" <<Metrics>> #85BBF0
    component argo_svc as "ArgoCD Service" <<NodePort>>
    component ksm as "kube-state-metrics" <<Metrics>> #85BBF0
    component ms as "metrics-server" <<Metrics>> #85BBF0
    component dash as "kubernetes-dashboard" <<Application>>

    node_exporter -[hidden]down- ksm
    ksm -[hidden]down- argo
    argo -[hidden]down- ms

    argo -right-> argo_svc
    ms -left-> dash

    note right of node_exporter: Running on all\nworker nodes and the\ncontrol plane node
    note left of node_exporter: NodePort config via Helm Chart
    note left of ksm: NodePort config via Helm Chart
}

component p as "Prometheus" <<Docker Container>>
component g as "Grafana" <<Docker Container>>
component be as "blackbox_exporter" <<Docker Container>>

node_exporter -right-> p
argo_svc -right-> p
ksm -right-> p

be -down--> p
p -down-> g

@enduml
```

### System Metrics (Node Exporter)

Each node in the Talos Kubernetes Cluster runs a `node_exporter` instance. The `node_exporter` is a Prometheus exporter for hardware and OS metrics. It exposes a wide variety of metrics, including CPU, memory, disk, and network usage.

- <http://talos-cp.fritz.box:30091>
- <http://talos-w1.fritz.box:30091>
- <http://talos-w2.fritz.box:30091>
- <http://talos-w3.fritz.box:30091>

### Kubernetes Metrics

[`kube-state-metrics`](https://github.com/kubernetes/kube-state-metrics) provides Kubernetes resource-level metrics, such as pod counts, namespace counts, and pod distribution.

- <http://talos-cp.fritz.box:30095>

The Kubernetes dashboards originate from <https://github.com/dotdc/grafana-dashboards-kubernetes?tab=readme-ov-file>. They carry the numeric prefix `30` inside this repository (the rest of the name remains unchanged).

| Dashboard                      | ID    |
|--------------------------------|------:|
| k8s-addons-prometheus.json     | 19105 |
| k8s-addons-trivy-operator.json | 16337 |
| k8s-system-api-server.json     | 15761 |
| k8s-system-coredns.json        | 15762 |
| k8s-views-global.json          | 15757 |
| k8s-views-namespaces.json      | 15758 |
| k8s-views-nodes.json           | 15759 |
| k8s-views-pods.json            | 15760 |

??? note "Metrics Server is not the way to expose metrics"
    **From the official docs:** The [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) is meant only for autoscaling purposes. For example, don't use it to forward metrics to monitoring solutions, or as a source of monitoring solution metrics. In such cases please collect metrics from Kubelet `/metrics/resource` endpoint directly.

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

The example dashboard is linked on the official Metrics Docs page: <https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/#dashboards>

??? note "Namespace for custom services to expose ArgoCD metrics"
    Even though our own monitoring and logging deployments are inside the `monitoring-logging` namespace, the custom services to expose ArgoCD metrics must be in the `argocd` namespace.

### Kubernetes Dashboard

The Kubernetes Dashboard is a general-purpose, web-based UI for Kubernetes clusters. It allows users to manage applications running in the cluster and troubleshoot them, as well as manage the cluster itself.

The Kubernetes Dashboard is deployed inside the Kubernetes cluster. In case the Prometheus-Grafana stack is down, we still have access to the Kubernetes Dashboard to inspect the cluster.

- Run `~/port-forward-kubernetes-dashboard.sh` on the `admin-pi.fritz.box` to retrieve a Bearer Token and to port-forward the Kubernetes Dashboards web interface.
<!-- - metrics-server: <http://talos-cp.fritz.box:30002> -->

<!-- ## Logging

Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. -->

## References / External Links

- For details on why we set up a dedicated monitoring stack on the `admin-pi`, see [ADR-002 - Talos RasPi: Prometheus and Grafana inside Kubernetes vs outside on the admin-pi vs Grafana Cloud](https://github.com/sommerfeld-io/configs-homelab/issues/35) on GitHub.
- ArgoCD Metrics
    - Official docs about [Argo CD exposing different sets of Prometheus metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics)
    - Blog post about [Enabling ArgoCD metrics and Monitoring Using Kube-Prometheus-Stack](https://medium.com/@randeniyamalitha08/enabling-argocd-metrics-and-monitoring-using-kube-prometheus-stack-ebece18c41d8)
