---
hide:
  - toc
---

# How to update ArgoCD

Our configuration was set up with the help of the [Argo-CD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable). The Argo-CD Autopilot is a tool which offers an opinionated way of installing Argo-CD and managing GitOps repositories.

The autopilot bootstrap command will deploy an Argo CD manifest to a target K8s cluster. This Application will manage the Argo CD installation itself - so after running this command, you will have an Argo CD deployment that manages itself through GitOps.

- [ ] The ArgoCD version is determined through the `components/talos-cluster/manifests/bootstrap/argo-cd/kustomization.yaml` file.
- [ ] To Update the ArgoCD version, just update `resources` URL in the the`kustomization.yaml` file to point to the desired version of ArgoCD.

??? note "Initial config from the ArgoCD Autopilot and its downside"
    - The initial config from the ArgoCD Autopilot points to [github.com/argoproj-labs/argocd-autopilot/manifests/base?ref=v0.4.18](https://github.com/argoproj-labs/argocd-autopilot/blob/main/manifests/base/kustomization.yaml) references a config which is marked as `stable`.
    - However, this means that we cannot determine the exact version of ArgoCD that is being deployed and hence cannot determine when to update ArgoCD ourselves.
    - We found a way around this by changing the `resources` URL in the `kustomization.yaml` file to point to a specific version of ArgoCD (see <https://github.com/sommerfeld-io/configs-homelab/blob/main/components/talos-cluster/manifests/bootstrap/argo-cd/kustomization.yaml>).
