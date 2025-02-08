# Talos Cluster - Telemetry

The namespace `telemetry` contains all components related to monitoring, logging and observability of the Talos Kubernetes Cluster. The name `telemetry` is inspired by the concept of collecting and analyzing system data.

## Prometheus & Grafana

The Prometheus & Grafana stack is deployed into the cluster itself through the [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/introduction). Prometheus Operator is a [Kubernetes Operator](https://github.com/cncf/tag-app-delivery/blob/main/operator-wg/whitepaper/Operator-WhitePaper_v1-0.md#foundation) that provides Kubernetes native deployment and management of [Prometheus](https://prometheus.io) and related monitoring components.

The Prometheus Operator is installed through a [Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack). The installation is done by ArgoCD.

## `node-exporter`

...

## `kube-state-metrics`

...

## ArgoCD metrics

...
