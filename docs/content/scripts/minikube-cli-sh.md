# minikube-cli

This script controls the local minikube instance. This setup includes Minikube and a Docker Compose stack. This script exclusively manages Minikube. Helm and all related Compose stacks. Minikube will not fail if the Docker Compose stacks are not running.

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

### Deployments
Installing and uninstalling apps is done with `helm` or ArgoCD. This script can handle some `helm` charts, but not all. All supported Helm charts can be selected from the menu.

#### Portainer
Portainer is deployed into Minikube to offer an additional method for inspecting and monitoring the Minikube cluster, complementing the existing Dashboard plugin.

To deploy Portainer in the Minikube cluster, you can select the respective action in the `minikube-cli` or deploy directly with `helm`.

```bash
cd components/minikube/admin-charts

helm install portainer ./portainer
helm uninstall portainer
```

!!! warning
    With this Portainer setup, a service account with `cluster-admin` permissions is used to enable Portainer to interact with the Kubernetes API. This high-level permission is necessary because it allows Portainer to query detailed information about the cluster, manage resources, and perform administrative tasks.

    This could be a security risk, so it is recommended to use Portainer in a controlled environment. This minikube setup is intended for development and testing purposes only. It is not recommended for production use.

For more information, see the Portainer Helm Chart in the [portainer/k8s GitHub repository](https://github.com/portainer/k8s).

### Increasing the NodePort range
By default, minikube only exposes ports `30000-32767`. If this does not work for you, you can adjust the range by using: `minikube start --extra-config=apiserver.service-node-port-range=1024-65535`

<!-- !    DO NOT EDIT DIRECTLY !!!!!                              -->
<!-- !    File is auto-generated by pipeline                      -->
<!-- !    Contents are based on files from docs/contents/about    -->
