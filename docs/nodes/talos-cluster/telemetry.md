# Talos Cluster - Telemetry

The namespace `telemetry` contains all components related to monitoring, logging and observability of the Talos Kubernetes Cluster. The name `telemetry` is inspired by the concept of collecting and analyzing system data.

- Grafana UI: <http://talos-cp.fritz.box:30000>

## Prometheus & Grafana

The Prometheus & Grafana stack is deployed into the cluster itself through the [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/introduction). Prometheus Operator is a [Kubernetes Operator](https://github.com/cncf/tag-app-delivery/blob/main/operator-wg/whitepaper/Operator-WhitePaper_v1-0.md#foundation) that provides Kubernetes native deployment and management of [Prometheus](https://prometheus.io) and related monitoring components.

The Prometheus Operator is installed through a [Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack). The installation is done by ArgoCD.

To access the Grafana UI, we added a `NodePort` service to the Grafana deployment. The service is exposed on port `30000`. We created a copy of the `kube-prometheus-stack-grafana` service inside the `telemetry` namespace and changed the service type to `NodePort`. The copy is named `kube-prometheus-stack-grafana-nodeport`.

??? note "Not included in this setup"
    - **Data Persistence:** By default, the operator configures Pods to store data on emptyDir volumes which aren't persisted when the Pods are redeployed. See <https://prometheus-operator.dev/docs/platform/storage>.
    - **Absent components**: The helm chart does not install all components of kube-prometheus, notably excluding the Prometheus Adapter and Prometheus black-box exporter. They may be added later if needed.

### ArgoCD metrics

[Argo CD exposes different sets of Prometheus metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics) per server. The Prometheus Operator scrapes the metrics from the Argo CD server through `ServiceMonitor` resources.

### Blackbox Exporter

The Blackbox Exporter is a tool that allows you to probe endpoints over HTTP, HTTPS, DNS, TCP, and ICMP.

When using `ServiceMonitor` resources with certain selectors, we can discover services automatically. In our case, all `Service` resources that carry the label `monitoring.sommerfeld.io/blackbox: enabled` are discovered by the Blackbox Exporter - regardless of the namespace.

!!! warning "Multiple endpoints for a service"
    - You will most likely see multiple endpoints for a single service due to the way Kubernetes Services and Endpoints work. A Kubernetes Service, even if it logically represents a single application, can have multiple addresses in its `Endpoints`. These endpoints correspond to the individual Pods that the Service's selector matches.
    - A `ServiceMonitor` is selecting Kubernetes Services based on the `matchLabels` under `spec.selector`. When it finds a Service that matches, it then looks at the endpoints defined for that Service. So it will discover all the endpoints for a Service, not just the Service itself.

When you don't specify a port name in the `ServiceMonitor`'s endpoints section, Prometheus, by default, will create a scrape target for each port defined in the `spec.ports` of the discovered Service.

## Kubernetes Dashboard

The Kubernetes Dashboard is a general-purpose, web-based UI for Kubernetes clusters. It allows users to manage applications running in the cluster and troubleshoot them, as well as manage the cluster itself.

The Kubernetes Dashboard is deployed inside the Kubernetes cluster. In case the Prometheus-Grafana stack is down, we still have access to the Kubernetes Dashboard to inspect the cluster.

- Run `~/port-forward-kubernetes-dashboard.sh` from the Vagrantbox (`components/talos-cluster/virtual-talos-admin/Vagrantfile`) to retrieve a Bearer Token and to port-forward the Kubernetes Dashboards web interface.
