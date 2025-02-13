#!/bin/bash

readonly NAMESPACE="telemetry"
readonly PORT="9000"
readonly SVC_PORT="9090"
readonly PROTOCOL="http"

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}$PROTOCOL://$HOSTNAME.fritz.box:$PORT${D}"
echo -e "[INFO]   ${Y}$PROTOCOL://localhost:$PORT${D}"
kubectl port-forward -n "$NAMESPACE" svc/prometheus-operated "$PORT:$SVC_PORT" --address 0.0.0.0
