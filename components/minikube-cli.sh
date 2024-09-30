#!/bin/bash
# @file minikube-cli.sh
# @brief Command line interface to run Minikube and Helm commands.
# @description
#   This script controls the local minikube instance. This setup includes Minikube and a Docker
#    Compose stack. This script exclusively manages Minikube. Helm and all related Compose stacks.
#    Minikube will not fail if the Docker Compose stacks are not running.
#
#   ```kroki-ditaa
#   +----------------------------------+
#   |  Workstation                     |
#   |                                  |
#   |    +------------------------+    |          +------------------------+
#   |    |  minikube              |    |          |  DockerHub             |
#   |    |                        |    |          |                        |
#   |    |    +--------------+    |    |   Helm   |    +--------------+    |
#   |    |    | Portainer    |<------------------------+ Portainer    |    |
#   |    |    +--------------+    |    |          |    +--------------+    |
#   |    |                        |    |          |                        |
#   |    |    +--------------+    |    |   Helm   |    +--------------+    |
#   |    |    | ArgoCD       |<------------------------+ ArgoCD       |    |
#   |    |    +--------------+    |    |          |    +--------------+    |
#   |    |                        |    |          +------------------------+
#   |    |       +----------------+    |
#   |    |       |      dashboard |    |
#   |    |       +----------------+    |
#   |    |       | metrics server |    |
#   |    +-------+---------+------+    |
#   |                      :           |
#   |                      |           |
#   |    +-----------------|------+    |
#   |    | DockerCompose   |      |    |
#   |    |                 v      |    |
#   |    |    +--------------+    |    |
#   |    |    | Prometheus   |    |    |
#   |    |    +--+-----------+    |    |
#   |    |       |                |    |
#   |    |       v                |    |
#   |    |    +--------------+    |    |
#   |    |    | Grafana      |    |    |
#   |    |    +--------------+    |    |
#   |    +------------------------+    |
#   |                                  |
#   +----------------------------------+
#   ```
#
#   Initial implementation issue took place with <https://github.com/sommerfeld-io/configs-homelab/issues/5>
#
#   ### About minikube and Helm
#   [minikube](link:) is a tool that simplifies running Kubernetes clusters locally. It allows
#   developers to set up a single-node Kubernetes cluster on their local workstation, which is
#   useful for development, testing, and learning purposes. minikube supports various hypervisors
#   (like VirtualBox, KVM, Hyper-V) and container runtimes (like Docker, Podman, containerd, and CRI-O).
#   By providing a local Kubernetes environment, minikube helps developers emulate the behavior of
#   a production cluster, enabling them to test Kubernetes applications in a controlled, local
#   setup before deploying them to a larger, more complex cluster.
#
#   [Helm](https://helm.sh) is a package manager for Kubernetes, designed to streamline the
#   deployment, management, and scaling of applications on Kubernetes clusters. It uses "charts",
#   which are packages of pre-configured Kubernetes resources, to define, install, and upgrade
#   Kubernetes applications. Helm helps automate the deployment process, manage dependencies, and
#   simplify updates and rollbacks, making it easier to manage  Kubernetes applications
#   consistently and reproducibly.
#
#   ### Prerequisites
#   A local Docker and a local minikube installation is required. To deploy applications to the
#   cluster, Helm is also required.
#
#   Keep in mind, that the Ansible playbook creates a `kubectl` alias which points to
#   `minikube kubectl` so this might conflict with other `kubectl` installations.
#
#   ### Usage
#   This script allows to start, stop and expose the dashboard (among others). Common commands
#   are available as options. The script is interactive and will prompt the user to select an
#   action. More specific actions need to be executed directly with `minikube`, `kubectl` or
#   `helm`.
#
#   ```bash
#   # Start the script from its location in the filesystem
#   ./minikube-cli.sh
#
#   # Start the script through a bash alias (written by ansible playbook)
#   minikube-cli
#   ```
#
#   The script does not accept any parameters.
#
#   #### Deployments
#   Installing and uninstalling apps is done with `helm` or ArgoCD. This script can handle some
#   `helm` charts, but not all. All supported Helm charts can be selected from the menu.
#
#   ##### Portainer
#   Portainer is deployed into Minikube to offer an additional method for inspecting and monitoring
#   the Minikube cluster, complementing the existing Dashboard plugin.
#
#   To deploy Portainer in the Minikube cluster, you can select the respective action in the
#   `minikube-cli` or deploy directly with `helm`.
#
#   ```bash
#   cd components/minikube/admin-charts
#
#   helm install portainer ./portainer
#   helm uninstall portainer
#   ```
#
#   With this Portainer setup, a service account with `cluster-admin` permissions is used to enable
#   Portainer to interact with the Kubernetes API. This high-level permission is necessary because
#   it allows Portainer to query detailed information about the cluster, manage resources, and
#   perform administrative tasks.
#
#   This could be a security risk, so it is recommended to use Portainer in a controlled
#   environment. This minikube setup is intended for development and testing purposes only. It is
#   not recommended for production use.
#
#   For more information, see the Portainer Helm Chart in the
#   [portainer/k8s GitHub repository](https://github.com/portainer/k8s).
#
#   #### Increasing the NodePort range
#   By default, minikube only exposes ports `30000-32767`. If this does not work for you, you can
#   adjust the range by using: `minikube start --extra-config=apiserver.service-node-port-range=1024-65535`


set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly CHART_ADMIN="admin-charts"

readonly OPTION_START="start"
readonly OPTION_STOP="stop"
readonly OPTION_DASHBOARD="open-dashboard"
readonly OPTION_PODS="list-pods"
readonly OPTION_SERVICES="list-services"
readonly OPTION_STATUS="status"
readonly OPTION_HELP="help"
readonly OPTION_DESTROY="destroy"
readonly OPTION_DEPLOY_ADMIN="deploy-$CHART_ADMIN"
readonly OPTION_UNDEPLOY_ADMIN="undeploy-$CHART_ADMIN"


# @description Utility function to startup minikube.
function startup() {
  echo -e "$LOG_INFO Startup minikube on ${P}${HOSTNAME}${D}"
  minikube start

  sleep 5s

  echo -e "$LOG_INFO Startup metrics-server"
  minikube addons enable metrics-server

  echo -e "$LOG_INFO Startup ingress addon"
  minikube addons enable ingress
}


# @description Utility function to shutdown minikube.
function shutdown() {
  echo -e "$LOG_INFO Shutdown minikube on ${P}${HOSTNAME}${D}"
  minikube stop
}


# @description Utility function to expose the minikube dashboad.
function dashboard() {
  echo -e "$LOG_INFO Expose the minikube dashboard"
  minikube dashboard
}


# @description Utility function to list pods.
function pods() {
  echo -e "$LOG_INFO List pods from all namespaces"
  minikube kubectl -- get po -A
}


# @description Utility function to list services from all namespaces.
function services() {
  echo -e "$LOG_INFO List services from all namespaces"
  minikube service list # --namespace apps
}


# @description Utility function to display minikube status and some metadata.
function status() {
  echo -e "$LOG_INFO minikube version"
  minikube version

  echo -e "$LOG_INFO Helm version"
  helm version

  echo -e "$LOG_INFO minikube status"
  minikube status
}


# @description Utility function to display the minikube help.
function help() {
  echo -e "$LOG_INFO minikube help"
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  echo -e "$LOG_WARN Remember to use minikube directly when invoking commands that are not supported by this script"
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  minikube
}


# @description Utility function to delete the minkube instance and clean everything up.
function destroy() {
  echo -e "$LOG_INFO minikube destroy"
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  echo -e "$LOG_WARN The minikube instance will be deleted."
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  minikube delete
}


# @description Utility function to deploy a Helm chart.
#
# @arg $1 string The folder name containing the Helm charts (based in `components/homelab/src/main/minikube`).
# @arg $2 string The sub folder name containing the actual deployment configuration.
function deploy() {
  (
    cd "minikube/$1" || exit

    echo -e "$LOG_INFO Deploy ${P}$1${D}/${P}$2${D} with helm"
    helm install "$2" "./$2"
  )
}


# @description Utility function to undeploy a Helm chart.
#
# @arg $1 string The sub folder name (= the release name) of the actual deployment configuration.
function undeploy() {
  (
    echo -e "$LOG_INFO Undeploy ${P}$1${D}"
    helm uninstall "$1"
  )
}


echo -e "$LOG_INFO Select the action"
select s in "$OPTION_START" \
            "$OPTION_STOP" \
            "$OPTION_DASHBOARD" \
            "$OPTION_DEPLOY_ADMIN" \
            "$OPTION_UNDEPLOY_ADMIN" \
            "$OPTION_PODS" \
            "$OPTION_SERVICES" \
            "$OPTION_STATUS" \
            "$OPTION_HELP" \
            "$OPTION_DESTROY"
  do
    case "$s" in
    "$OPTION_START" )
        startup
        break;;
    "$OPTION_STOP" )
        shutdown
        break;;
    "$OPTION_DASHBOARD" )
        dashboard
        break;;
    "$OPTION_DEPLOY_ADMIN" )
        deploy "$CHART_ADMIN" portainer
        break;;
    "$OPTION_UNDEPLOY_ADMIN" )
        undeploy portainer
        break;;
    "$OPTION_PODS" )
        pods
        break;;
    "$OPTION_SERVICES" )
        services
        break;;
    "$OPTION_STATUS" )
        status
        break;;
    "$OPTION_HELP" )
        help
        break;;
    "$OPTION_DESTROY" )
        destroy
        break;;
    esac
done
