# Talos Cluster - Network & Gateway Setup

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam nec pur elit sed nunc luctus tincidunt. Nullam nec pur elit sed nunc luctus tincidunt. Nullam nec pur elit sed non luctus tincidunt. Nullam nec pur elit sed nunc luctus tincidunt. Nullam nec pur elit sed nunc luctus tincidunt. Nullam nec pur elit sed non luctus tincidunt. Nullam nec pur elit sed nunc luctus tincidunt.

!!! warning "TODO"
    - Write an Introduction!
    - Something about the network setup: Whe handles DNS for the network? Which IP of which talos node is configured for `*.talos-cluster.fritz.box`.
    - Something about k8s Services: Are services exposed on all nodes or on specific nodes only? Diagram!!

## Nginx Gateway Fabric

We use [Nginx Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/overview/gateway-architecture) to expose services through human-readable URLs.

Nginx Gateway Fabric is an open source project that provides an implementation of the [Gateway API](https://gateway-api.sigs.k8s.io) using [Nginx](https://nginx.org) as the data plane. The goal of this project is to implement the core Gateway APIs – Gateway, GatewayClass, HTTPRoute, GRPCRoute, TCPRoute, TLSRoute, and UDPRoute – to configure an HTTP or TCP/UDP load balancer, reverse proxy, or API gateway for applications running on Kubernetes. Nginx Gateway Fabric supports a subset of the Gateway API.

The Gateway API resources must be installed first because Nginx Gateway Fabric relies on these Kubernetes Custom Resource Definitions (CRDs). To ensure proper deployment order, configure sync waves by adding an annotation to both Applications.

For the configuration, see:

- `components/talos-cluster/manifests/bootstrap/cluster-resources/in-cluster/gateway.yaml`
- `components/talos-cluster/manifests/bootstrap/cluster-resources/in-cluster/gateway-fabric.yaml`
