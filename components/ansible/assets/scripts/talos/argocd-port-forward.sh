#!/bin/bash

echo "[INFO] ArgoCD Admin Password --------------------"
echo -e "${Y}"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "${D}"
echo

echo "[INFO] Port Forward -----------------------------"
echo -e "[INFO]   ${Y}https://$HOSTNAME.fritz.box:8080${D}"
kubectl port-forward -n argocd svc/argocd-server 8080:80 --address 0.0.0.0
