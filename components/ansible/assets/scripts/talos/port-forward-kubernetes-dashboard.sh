#!/bin/bash

readonly NAMESPACE="monitoring-logging"
readonly PORT="8000" # 8000 = http, 8001 = https
readonly SERVICE_ACCOUNT="kubernetes-dashboard-web"

function protocol() {
  if [ "$PORT" -eq "8001" ]; then
    echo "https"
  else
    echo "http"
  fi
}

PROTOCOL=$(protocol)
readonly PROTOCOL

echo "[INFO] Bearer Token -----------------------------"
echo -e "${Y}"
kubectl -n "$NAMESPACE" create token "$SERVICE_ACCOUNT"
echo -e "${D}"

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}$PROTOCOL://$HOSTNAME.fritz.box:$PORT${D}"
kubectl port-forward -n "$NAMESPACE" svc/kubernetes-dashboard-web "$PORT:$PORT" --address 0.0.0.0
