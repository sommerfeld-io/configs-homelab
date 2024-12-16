# How to interact with the Talos cluster

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
