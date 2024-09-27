#!/bin/bash
## TODO ... docs from docs/content/scripts/minikube-cli-sh.md
## TODO ... auto-generated Markdown file
## TODO ... Update path in components/ansible/tasks/ubuntu-minikube.yml (bash alias)

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


## Utility function to startup minikube.
function startup() {
  echo -e "$LOG_INFO Startup minikube on ${P}${HOSTNAME}${D}"
  minikube start

  sleep 5s

  echo -e "$LOG_INFO Startup metrics-server"
  minikube addons enable metrics-server

  echo -e "$LOG_INFO Startup ingress addon"
  minikube addons enable ingress
}


## Utility function to shutdown minikube.
function shutdown() {
  echo -e "$LOG_INFO Shutdown minikube on ${P}${HOSTNAME}${D}"
  minikube stop
}


## Utility function to expose the minikube dashboad.
function dashboard() {
  echo -e "$LOG_INFO Expose the minikube dashboard"
  minikube dashboard
}


## Utility function to list pods.
function pods() {
  echo -e "$LOG_INFO List pods from all namespaces"
  minikube kubectl -- get po -A
}


## Utility function to list services from all namespaces.
function services() {
  echo -e "$LOG_INFO List services from all namespaces"
  minikube service list # --namespace apps
}


## Utility function to display minikube status and some metadata.
function status() {
  echo -e "$LOG_INFO minikube version"
  minikube version

  echo -e "$LOG_INFO Helm version"
  helm version

  echo -e "$LOG_INFO minikube status"
  minikube status
}


## Utility function to display the minikube help.
function help() {
  echo -e "$LOG_INFO minikube help"
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  echo -e "$LOG_WARN Remember to use minikube directly when invoking commands that are not supported by this script"
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  minikube
}


## Utility function to delete the minkube instance and clean everything up.
function destroy() {
  echo -e "$LOG_INFO minikube destroy"
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  echo -e "$LOG_WARN The minikube instance will be deleted."
  echo -e "$LOG_WARN ----------------------------------------------------------------------------------------------"
  minikube delete
}


## Utility function to deploy a Helm chart.
##
## @arg $1 string The folder name containing the Helm charts (based in `components/homelab/src/main/minikube`).
## @arg $2 string The sub folder name containing the actual deployment configuration.
function deploy() {
  (
    cd "src/main/minikube/$1" || exit

    echo -e "$LOG_INFO Deploy ${P}$1${D}/${P}$2${D} with helm"
    helm install "$2" "./$2"
  )
}


## Utility function to undeploy a Helm chart.
##
## @arg $1 string The sub folder name (= the release name) of the actual deployment configuration.
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
