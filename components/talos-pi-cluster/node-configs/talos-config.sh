#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly CLUSTER_NAME="talos-pi-cluster"
readonly CLUSTER_ENDPOINT="https://talos-control-pi.fritz.box:6443"

readonly OUTPUT_DIR="generated"

readonly CONTROL_PLANE_NODE="talos-control-pi"
readonly WORKER_NODES=(
  "talos-worker-pi-1"
  "talos-worker-pi-2"
  "talos-worker-pi-3"
)


if [ -f "$CONTROL_PLANE_NODE.yaml" ]; then
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


echo "[INFO] Bootstrap cluster --------------------------------------"
talosctl bootstrap --nodes "$CONTROL_PLANE_NODE.fritz.box" \
  --endpoints "$CONTROL_PLANE_NODE.fritz.box"


echo "[INFO] Copy talos config into home dir ------------------------"
cp talosconfig ~/.talos/config


echo "[INFO] Generate kubectl config --------------------------------"
echo "[INFO] Add (merge) new cluster into local Kubernetes config"
talosctl kubeconfig

echo "[INFO] Cleanup ------------------------------------------------"
mv controlplane.yaml "$OUTPUT_DIR/controlplane.yaml"
mv worker.yaml "$OUTPUT_DIR/worker.yaml"
