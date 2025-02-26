# Gatekeeper

??? note "Gatekeeper resources are cluster-scoped resources"
    - ConstraintTemplate and Constraint resources are generally designed to be cluster-scoped. This means they apply to all namespaces within the Kubernetes cluster.
    - Their purpose is to enforce policies at a cluster level, affecting resources regardless of which namespace they reside in.
    - Therefore, specifying a namespace in their metadata is typically unnecessary and often undesirable.

The `ConstraintTemplate` defines the resource kind of the actual constraint.

```kroki-ditaa
+-------------------------------------------------+
|                                                 |
|  apiVersion: templates.gatekeeper.sh/v1beta1    |
|  kind: ConstraintTemplate                       |
|  metadata:                                      |
|    name: gatekeeper-template-application        |
|  spec:                                          |
|    crd:                                         |
|      spec:                                      |
|        names:                                   |
|          kind: GatekeeperConstraintApplication  +-------+
|                                                 |       |
+-------------------------------------------------+       |
                                                          |
                                                          |
+-------------------------------------------------+       |
|                                                 |       |
|  apiVersion: constraints.gatekeeper.sh/v1beta1  |       |
|  kind: GatekeeperConstraintApplication          +<------+
|  metadata:                                      |
|    name: gatekeeper-constraint-application      |
|                                                 |
+-------------------------------------------------+
```

## Rules for ArgoCD applications

- `ConstraintTemplate` (`gatekeeper-template-application`):
    - This defines the Rego policy that will be enforced.
    - It takes two parameters: requiredAnnotations and requiredFinalizers, both arrays of strings.
    - The Rego code iterates through the required annotations and finalizers, checking if they exist in the Argo CD Application object.
    - If any are missing, it generates a violation message.
    - It has two distinct violation rules, one for annotations, and the other for finalizers. This provides clearer error messages.
    - The rego code has the helper functions has_annotation and has_finalizer which makes the code more readable.
- `Constraint` (`gatekeeper-constraint-application`):
    - This applies the constraint template to all Argo CD Application resources.
    - It sets the requiredAnnotations parameter to ["argocd.argoproj.io/sync-wave"] and the requiredFinalizers parameter to ["resources-finalizer.argocd.argoproj.io"].
    - The match section now explicitly targets `argoproj.io/Application` kinds.
