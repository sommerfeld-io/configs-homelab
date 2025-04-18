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

Endpoint monitoring refers to monitoring internal and external endpoints (HTTP/S, DNS, TCP, and ICMP) for various parameters including HTTP latencies, DNS lookup latencies, SSL certificate expiry information, TLS version.

In a Kubernetes system, not just the external endpoints that need to be monitored, internal endpoints are also required to be monitored for latency and other parameters.

Blackbox Exporter is used to probe endpoints like HTTPS, HTTP, TCP, DNS, and ICMP. After you define the endpoint, Blackbox Exporter generates metrics that can be visualized using tools like Grafana. One of the most important feature of Blackbox Exporter is measuring the response time of endpoints.

## Kubernetes Dashboard

The Kubernetes Dashboard is a general-purpose, web-based UI for Kubernetes clusters. It allows users to manage applications running in the cluster and troubleshoot them, as well as manage the cluster itself.

The Kubernetes Dashboard is deployed inside the Kubernetes cluster. In case the Prometheus-Grafana stack is down, we still have access to the Kubernetes Dashboard to inspect the cluster.

- Run `~/port-forward-kubernetes-dashboard.sh` from the Vagrantbox (`components/talos-cluster/virtual-talos-admin/Vagrantfile`) to retrieve a Bearer Token and to port-forward the Kubernetes Dashboards web interface.

## See also

- Blog Post [How to Monitor Endpoints in Kubernetes using Blackbox Exporter](https://www.infracloud.io/blogs/monitoring-endpoints-kubernetes-blackbox-exporter)
