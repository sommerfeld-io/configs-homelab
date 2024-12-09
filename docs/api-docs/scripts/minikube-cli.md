# minikube-cli.sh

Command line interface to run Minikube and Helm commands. This script controls the local minikube instance. This setup includes Minikube and a Docker

Compose stack. This script exclusively manages Minikube. Helm and all related Compose stacks. Minikube will not fail if the Docker Compose stacks are not running.

```kroki-ditaa
+----------------------------------+
|  Workstation                     |
|                                  |
|    +------------------------+    |          +------------------------+
|    |  minikube              |    |          |  DockerHub             |
|    |                        |    |          |                        |
|    |    +--------------+    |    |   Helm   |    +--------------+    |
|    |    | Portainer    |<------------------------+ Portainer    |    |
|    |    +--------------+    |    |          |    +--------------+    |
|    |                        |    |          |                        |
|    |    +--------------+    |    |   Helm   |    +--------------+    |
|    |    | ArgoCD       |<------------------------+ ArgoCD       |    |
|    |    +--------------+    |    |          |    +--------------+    |
|    |                        |    |          +------------------------+
|    |       +----------------+    |
|    |       |      dashboard |    |
|    |       +----------------+    |
|    |       | metrics server |    |
|    +-------+---------+------+    |
|                      :           |
|                      |           |
|    +-----------------|------+    |
|    | DockerCompose   |      |    |
|    |                 v      |    |
|    |    +--------------+    |    |
|    |    | Prometheus   |    |    |
|    |    +--+-----------+    |    |
|    |       |                |    |
|    |       v                |    |
|    |    +--------------+    |    |
|    |    | Grafana      |    |    |
|    |    +--------------+    |    |
|    +------------------------+    |
|                                  |
+----------------------------------+
```

Initial implementation issue took place with <https://github.com/sommerfeld-io/configs-homelab/issues/5>

## About minikube and Helm

[minikube](link:) is a tool that simplifies running Kubernetes clusters locally. It allows developers to set up a single-node Kubernetes cluster on their local workstation, which is useful for development, testing, and learning purposes. minikube supports various hypervisors (like VirtualBox, KVM, Hyper-V) and container runtimes (like Docker, Podman, containerd, and CRI-O). By providing a local Kubernetes environment, minikube helps developers emulate the behavior of a production cluster, enabling them to test Kubernetes applications in a controlled, local setup before deploying them to a larger, more complex cluster.

[Helm](https://helm.sh) is a package manager for Kubernetes, designed to streamline the deployment, management, and scaling of applications on Kubernetes clusters. It uses "charts", which are packages of pre-configured Kubernetes resources, to define, install, and upgrade Kubernetes applications. Helm helps automate the deployment process, manage dependencies, and simplify updates and rollbacks, making it easier to manage  Kubernetes applications consistently and reproducibly.

## Prerequisites

A local Docker and a local minikube installation is required. To deploy applications to the cluster, Helm is also required.

Keep in mind, that the Ansible playbook creates a `kubectl` alias which points to `minikube kubectl` so this might conflict with other `kubectl` installations.

## Usage

This script allows to start, stop and expose the dashboard (among others). Common commands are available as options. The script is interactive and will prompt the user to select an action. More specific actions need to be executed directly with `minikube`, `kubectl` or `helm`.

```bash
# Start the script from its location in the filesystem
./minikube-cli.sh

# Start the script through a bash alias (written by ansible playbook)
minikube-cli
```

The script does not accept any parameters.

### Argo CD

[Argo CD](https://argo-cd.readthedocs.io/en/stable) is a declarative, GitOps continuous delivery tool for Kubernetes. Application definitions, configurations, and environments should be declarative and version controlled. Application deployment and lifecycle management should be automated, auditable, and easy to understand.

```kroki-plantumk
@startuml

skinparam linetype ortho

component Minikube {
   component ArgoCD
   collections Apps
   note left of Apps: Including k8s config

ArgoCD -down-> Apps : Deploy
}

card GitHub {
   database Repo {
       card cfg as "Argo Config"
       card Manifests
       Manifests -[hidden]down- cfg
   }
}

cfg -left~> Minikube
ArgoCD -right-> Manifests : Watch

@enduml
```

### Increasing the NodePort range

By default, minikube only exposes ports `30000-32767`. If this does not work for you, you can
adjust the range by using: `minikube start --extra-config=apiserver.service-node-port-range=1024-65535`
