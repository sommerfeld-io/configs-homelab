# How to route Requests to Services

To route requests to services in the Talos Cluster, we rely on Ingress Controllers and DNS.

Inside Kubernetes the Ingress Controller is responsible for routing incoming requests to the correct service based on the hostname.

Outside of Kubernetes the DNS server is responsible for resolving the hostname to the correct IP address of the Ingress Controller. This allows reacting to requests inside Kubernetes in the first place.

We use the [Ingress Nginx Controller.](https://kubernetes.github.io/ingress-nginx). It is built around the [Kubernetes Ingress resource](https://kubernetes.io/docs/concepts/services-networking/ingress), using a [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap) to store the controller configuration.

!!! warning "TODO"
    - Something about the network setup: Who handles DNS for the network? Which IP of which talos node is configured for `*.talos-cluster.fritz.box`.
    - With a Diagram!
    - Something about k8s Services: Are services exposed on all nodes or on specific nodes only? Diagram!!
