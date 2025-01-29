#!/bin/bash

# Kubernetes Docs: Authentication
# https://github.com/kubernetes/dashboard/blob/v2.0.0/docs/user/access-control/README.md#authentication

readonly PORT="8000"
readonly PROTOCOL="http"

readonly NAMESPACE="monitoring-logging"
readonly SERVICE_ACCOUNT="kubernetes-dashboard-web"

echo "[INFO] Bearer Token -----------------------------"
echo -e "${Y}"
kubectl -n "$NAMESPACE" create token "$SERVICE_ACCOUNT"
echo -e "${D}"

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}$PROTOCOL://$HOSTNAME.fritz.box:$PORT${D}"
kubectl port-forward -n "$NAMESPACE" svc/kubernetes-dashboard-web "$PORT:$PORT" --address 0.0.0.0
