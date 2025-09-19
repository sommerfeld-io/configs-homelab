# Role: Minikube

This role installs and configures Minikube, a tool for running Kubernetes clusters locally. Additionally it installs Helm, a package manager for Kubernetes, and all dependencies expect for the virtualization provider.

Minikube automatically selects the virtualization provider based on the host system. Just make sure Docker is installed before starting minikube.

This role is intended to be used on Ubuntu Desktop machines.

## Expected Variables

- `{{ ansible_user }}`: The user to install for (typically the logged-in user).
