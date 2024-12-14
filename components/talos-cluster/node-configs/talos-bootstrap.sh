#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly CLUSTER_NAME="talos-cluster"
readonly CLUSTER_ENDPOINT="https://talos-cp.fritz.box:6443"

readonly OUTPUT_DIR="generated"

readonly CONTROL_PLANE_NODE="talos-cp"
readonly WORKER_NODES=(
  "talos-w1"
  "talos-w2"
  "talos-w3"
)

export GIT_REPO="https://github.com/sommerfeld-io/configs-homelab.git/components/talos-cluster/manifests"
readonly ARGO_PROJECT="$CLUSTER_NAME"


if [ -f "$OUTPUT_DIR/$CONTROL_PLANE_NODE.yaml" ]; then
  echo "[ERROR] $CONTROL_PLANE_NODE.yaml config file already exists."
  echo "[ERROR] Abort script to avoid overwriting existing configs."
  echo "[ERROR] This would most likely result in a broken cluster (config)."
  echo "[ERROR] Newly generated configs surly conflict with certs and PKI"
  echo "[ERROR] and leave the cluster in an unmanageable state."
  exit 8
fi


# Patch the config for the given node.
#
# @args $1: The node name
# @args $2: The default config file (controlplane.yaml or worker.yaml) that should be patched
function patch() {
  echo "[INFO] Patch $2 to $1.yaml"
  talosctl machineconfig patch "$2" \
    --patch "@$1-patch.yml" \
    --output "$OUTPUT_DIR/$1.yaml"
}


# Apply the config for the given node.
#
# @args $1: The node name
function apply() {
  echo "[INFO] Apply $1"

  talosctl apply-config --insecure \
    --nodes "$1.fritz.box" \
    --file "$OUTPUT_DIR/$1.yaml"
}


echo "[INFO] Github Token for ArgoCD Autopilot ---------------------"
echo "[INFO] Github Repo = $GIT_REPO"
read -s -r -p "Enter Token: " GIT_TOKEN
export GIT_TOKEN
echo


echo "[INFO] Create output directory -------------------------------"
mkdir -p "$OUTPUT_DIR"


echo "[INFO] Generating Talos config --------------------------------"
talosctl gen config "$CLUSTER_NAME" "$CLUSTER_ENDPOINT"


echo "[INFO] Patch node configs -------------------------------------"
patch "$CONTROL_PLANE_NODE" "controlplane.yaml"

for worker in "${WORKER_NODES[@]}"; do
  patch "$worker" "worker.yaml"
done


echo "[INFO] Apply node configs -------------------------------------"
apply "$CONTROL_PLANE_NODE"

for worker in "${WORKER_NODES[@]}"; do
  apply "$worker"
done


echo "[INFO] Copy talos config into home dir ------------------------"
cp talosconfig ~/.talos/config


echo "[INFO] Bootstrap cluster --------------------------------------"
sleep 5s
talosctl bootstrap --nodes "$CONTROL_PLANE_NODE.fritz.box" \
  --endpoints "$CONTROL_PLANE_NODE.fritz.box"


echo "[INFO] Generate kubectl config --------------------------------"
echo "[INFO] Add (merge) new cluster into local Kubernetes config"
talosctl kubeconfig --nodes "$CONTROL_PLANE_NODE.fritz.box" \
  --endpoints "$CONTROL_PLANE_NODE.fritz.box"

echo "[INFO] Cleanup ------------------------------------------------"
mv controlplane.yaml "$OUTPUT_DIR/controlplane.yaml"
mv worker.yaml "$OUTPUT_DIR/worker.yaml"
mv talosconfig "$OUTPUT_DIR/talosconfig.yaml"

echo "[INFO] kubectl get nodes --------------------------------------"
kubectl get nodes

echo "[INFO] Bootstrap ArgoCD with ArgoCD Autopilot -----------------"
echo "[INFO] Bootstrap ArgoCD"
argocd-autopilot repo bootstrap

echo "[INFO] Create Project"
argocd-autopilot project create "$ARGO_PROJECT"


echo "[INFO] kubectl get all --all-namespaces -----------------------"
sleep 5s
kubectl get all --all-namespaces
