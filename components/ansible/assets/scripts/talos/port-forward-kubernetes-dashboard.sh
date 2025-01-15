#!/bin/bash

readonly NAMESPACE="monitoring-logging"
readonly PORT="8000"
readonly SERVICE_ACCOUNT="kubernetes-dashboard-web"

echo "[INFO] Bearer Token -----------------------------"
echo -e "${Y}"
kubectl -n "$NAMESPACE" create token "$SERVICE_ACCOUNT"
echo -e "${D}"
echo

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}https://$HOSTNAME.fritz.box:$PORT${D}"
kubectl port-forward -n "$NAMESPACE" svc/kubernetes-dashboard-web "$PORT:$PORT" --address 0.0.0.0
