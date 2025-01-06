# How to route Requests to Services

To route requests to services in the Talos Cluster, we rely on Ingress Controllers and DNS.

We use the [Ingress Nginx Controller.](https://kubernetes.github.io/ingress-nginx). It is built around the [Kubernetes Ingress resource](https://kubernetes.io/docs/concepts/services-networking/ingress), using a [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap) to store the controller configuration.

Inside Kubernetes the Ingress Controller is responsible for routing incoming requests to the correct service based on the hostname.

Outside of Kubernetes the DNS server of the FritzBox is responsible for resolving the hostname to the correct IP address of the Ingress Controller. This allows reacting to requests inside Kubernetes in the first place.

```kroki-plantuml
@startuml

skinparam linetype ortho
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9
skinparam ArrowFontColor #E2E4E9

skinparam ComponentFontColor #E2E4E9
skinparam ComponentBorderColor #666

skinparam NodeFontColor #E2E4E9
skinparam NodeBorderColor #E2E4E9
skinparam NodeBackgroundColor #14151A

skinparam FileFontColor #E2E4E9
skinparam FileBorderColor #E2E4E9
skinparam FileBackgroundColor transparent

skinparam ControlFontColor #E2E4E9
skinparam ControlBorderColor #E2E4E9
skinparam ControlBackgroundColor transparent

skinparam CollectionsFontColor #E2E4E9
skinparam CollectionsBorderColor #E2E4E9
skinparam CollectionsBackgroundColor #1E2129

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

component Router <<FritzBox>> {
    file DNS <<Config>>
}

component Talos <<Kubernetes>> {
    node cp as "talos-cp" <<Control Plane>>

    node w1 as "talos-w1" <<Worker Node>> {
        control ic as "Ingress Controller"
        collections s1 as "Services"
    }

    node w2 as "talos-w2" <<Worker Node>> {
        collections s2 as "Services"
    }

    node w3 as "talos-w3" <<Worker Node>> {
        collections s3 as "Services"
    }

    w2 -[hidden]down-> cp

    ic -right-> s1
    ic -left-> s2
    ic -left-> s3
}

DNS -down-> ic

@enduml
```

!!! warning "TODO"
    - Something about the network setup: Who handles DNS for the network? Which IP of which talos node is configured for `*.talos-cluster.fritz.box`.
    - With a Diagram!
    - Something about k8s Services: Are services exposed on all nodes or on specific nodes only? Diagram!!
