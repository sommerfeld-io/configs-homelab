#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly CLUSTER_NAME="talos-cluster"
export GIT_REPO="https://github.com/sommerfeld-io/configs-homelab.git/components/talos-cluster/manifests"
readonly ARGO_PROJECT="$CLUSTER_NAME"


echo "[INFO] Github Token for ArgoCD Autopilot ---------------------"
echo "[INFO] Github Repo = $GIT_REPO"
read -s -r -p "Enter Token: " GIT_TOKEN
export GIT_TOKEN
echo


echo "[INFO] Bootstrap ArgoCD with ArgoCD Autopilot -----------------"
echo "[INFO] Bootstrap ArgoCD"
sleep 5s
argocd-autopilot repo bootstrap


echo "[INFO] Create Project"
argocd-autopilot project create "$ARGO_PROJECT"


echo "[INFO] kubectl get all --all-namespaces -----------------------"
sleep 15s
kubectl get all --all-namespaces
