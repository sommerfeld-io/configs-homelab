# How to update ArgoCD

Our configuration was set up with the help of the [Argo-CD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable). The Argo-CD Autopilot is a tool which offers an opinionated way of installing Argo-CD and managing GitOps repositories.

The autopilot bootstrap command will deploy an Argo CD manifest to a target K8s cluster. This Application will manage the Argo CD installation itself - so after running this command, you will have an Argo CD deployment that manages itself through GitOps.

!!! warning "TODO"
    Still to do ...