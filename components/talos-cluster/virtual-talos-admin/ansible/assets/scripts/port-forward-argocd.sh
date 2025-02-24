#!/bin/bash

readonly NAMESPACE="argocd"
readonly PORT="8080"
readonly PROTOCOL="https"

echo "[INFO] ArgoCD Admin Password --------------------"
echo -e "${Y}"
kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "${D}"
echo

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}$PROTOCOL://$HOSTNAME.fritz.box:$PORT${D}"
echo -e "[INFO]   ${Y}$PROTOCOL://localhost:$PORT${D}"
kubectl port-forward -n "$NAMESPACE" svc/argocd-server "$PORT:80" --address 0.0.0.0
