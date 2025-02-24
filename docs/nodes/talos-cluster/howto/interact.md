# How to interact with the Talos Cluster

This guide provides an overview of how to interact with a Talos-managed Kubernetes cluster using talosctl and kubectl, the primary tools for managing and interacting with Talos nodes and Kubernetes workloads respectively.

You can use the `virtual-talos-admin` Vagrantbox to interact with the Talos Cluster. The `virtual-talos-admin` Vagrantbox is pre-configured with `talosctl`, `kubectl`, and `k9s`. The `kubeconfig` file is already configured to point to the Talos cluster. The provisioning is done by Ansible and the playbook for the Vagrantbox.

```bash
vagrant destroy -f

vagrant up
vagrant ssh
```

## `talosctl`

`talosctl` is available on the Admin VM node. The tool expects flags to identify the targeted node and the cluster management endpoint.

```bash
talosctl --nodes talos-cp.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w1.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w2.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w3.fritz.box --endpoints talos-cp.fritz.box dashboard
talosctl --nodes talos-w4.fritz.box --endpoints talos-cp.fritz.box dashboard
```

To avoid specifying the flags every time, the Ansible playbook wrote aliases onto the Admin VM node.

```bash
talosctl-cp dashboard
talosctl-w1 dashboard
talosctl-w2 dashboard
talosctl-w3 dashboard
talosctl-w4 dashboard
```

## `kubectl`

`kubectl` can be used from the Admin VM right away. The `kubeconfig` file is already configured to point to the Talos cluster. The `bootstrap-talos.sh` merged the config into `~/.kube/config`.

!!! note "A word on Infrastructure as Code"
    Keep in mind, that we treat everything as code. So we avoid running e.g. `kubectl apply` commands entirely. Instead, we use ArgoCD to manage the applications and configurations deployed to the Talos Cluster. There might be times when a PoC for e.g. Terraform establishes new ways to deploy applications to Kubernetes. But these PoCs still follow Infrastructure as Code principles.

## `k9s`

`k9s` is a terminal-based UI to interact with Kubernetes clusters. The tool is installed on the Admin VM and uses the same `kubeconfig` file as `kubectl`.

## ArgoCD

To interact with your Talos Cluster through ArgoCD, follow these steps:

1. Run `~/port-forward-argocd.sh` on the Admin VM to retrieve the default admin password and to port-forward the ArgoCD server's service.

1. **Access ArgoCD from a Browser:** Once port-forwarding is active, open a web browser and navigate to <https://admin-pi.fritz.box:8080>. You will likely see a security warning due to the self-signed certificate. You can safely ignore this warning and proceed to the login page.

1. **Login to ArgoCD:** On the login page, use the default credentials to log in:

    ```plaintext
    Username: admin
    Password: The password retrieved in step 1
    ```

    Once logged in, you will have access to the ArgoCD dashboard where you can manage your applications and configurations deployed to the Talos Cluster.
