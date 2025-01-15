#!/bin/bash

readonly NAMESPACE="argocd"
readonly PORT="8000"

echo "[INFO] ArgoCD Admin Password --------------------"
echo -e "${Y}"
kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "${D}"
echo

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}https://$HOSTNAME.fritz.box:$PORT${D}"
kubectl port-forward -n "$NAMESPACE" svc/argocd-server "$PORT:80" --address 0.0.0.0
