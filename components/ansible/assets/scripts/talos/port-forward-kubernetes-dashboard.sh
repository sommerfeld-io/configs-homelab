#!/bin/bash

# Kubernetes Docs: Authentication
# https://github.com/kubernetes/dashboard/blob/v2.0.0/docs/user/access-control/README.md#authentication

readonly PORT="8443"
readonly SVC_PORT="443"
readonly PROTOCOL="https"

readonly NAMESPACE="kubernetes-dashboard"
readonly APP_NAME="$NAMESPACE-helm-chart"
readonly SERVICE_ACCOUNT="$APP_NAME-kong"
readonly CLUSTER_ROLE_NAME="$APP_NAME-read-only"

echo "[INFO] Setup ------------------------------------"
echo "[INFO] ClusterRole"
kubectl create clusterrole "$CLUSTER_ROLE_NAME" \
  --verb=get,list,watch \
  --resource='*' \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] ClusterRoleBinding"
kubectl create clusterrolebinding "$CLUSTER_ROLE_NAME" \
  --clusterrole="$CLUSTER_ROLE_NAME" \
  --serviceaccount="$NAMESPACE:$SERVICE_ACCOUNT" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] Bearer Token -----------------------------"
echo -e "${Y}"
kubectl -n "$NAMESPACE" create token "$SERVICE_ACCOUNT"
echo -e "${D}"

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}$PROTOCOL://$HOSTNAME.fritz.box:$PORT${D}"
echo -e "[INFO]   ${Y}$PROTOCOL://localhost:$PORT${D}"
kubectl -n "$NAMESPACE" port-forward "svc/$APP_NAME-kong-proxy" "$PORT:$SVC_PORT" --address 0.0.0.0
