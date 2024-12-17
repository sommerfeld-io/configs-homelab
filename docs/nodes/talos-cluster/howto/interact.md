# How to interact with the Talos Cluster

This guide provides an overview of how to interact with a Talos-managed Kubernetes cluster using talosctl and kubectl, the primary tools for managing and interacting with Talos nodes and Kubernetes workloads respectively.

## `talosctl`

`talosctl` expects flags to identify the targeted node and the cluster management endpoint.

```bash
talosctl --nodes talos-cp.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w1.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w2.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w3.fritz.box --endpoints talos-cp.fritz.box dashboard
```

To avoid specifying the flags every time, the Ansible playbook wrote aliases onto the `admin-pi` node.

```bash
talosctl-cp dashboard
talosctl-w1 dashboard
talosctl-w2 dashboard
talosctl-w3 dashboard
```

## `kubectl`

`kubectl` can be used from the `admin-pi` right away. The `kubeconfig` file is already configured to point to the Talos cluster. The `bootstrap-talos.sh` merged the config into `~/.kube/config`.

## k9s

`k9s` is a terminal-based UI to interact with Kubernetes clusters. The tool is installed on the `admin-pi` and uses the same `kubeconfig` file as `kubectl`.

## ArgoCD

!!! warning "TODO"
    How to login? User/Pass? URL?
