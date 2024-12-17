# How to deploy an Application with ArgoCD

This guide explains how to deploy applications into the Talos Cluster with ArgoCD using the app-of-apps pattern.

## The App-of-Apps Pattern

The app-of-apps pattern is a strategy where a single ArgoCD Application resource manages other Application resources. This approach allows you to organize and deploy multiple applications efficiently. By using a parent application to define and synchronize other applications, you achieve a hierarchical structure that simplifies management and scalability. Each child application can reside in its own folder or YAML file, making it modular and easier to maintain.

### Benefits of the App-of-Apps Pattern

- **Centralized Management:** The parent application acts as a single point of control for all child applications.
- **Modularity:** Each application can be managed independently, allowing for granular updates and configurations.
- **Scalability:** Easily add or remove applications without impacting the parent configuration.
- **Clarity:** The folder structure provides clear organization of applications.

## Configuration Overview

In this setup, the `components/talos-cluster/manifests/bootstrap/root-application.yaml` file is the key to establishing the app-of-apps pattern. This file defines the parent application, which manages all child applications located within the `components/talos-cluster/manifests/apps` directory. All apps from this directory are synchronized automatically.

### Root Application

The `root-application.yaml` file is the entry point for the app-of-apps pattern. It specifies the child applications by pointing to their manifests within the `apps` directory. When ArgoCD syncs this root application, it automatically discovers and applies the configurations of all defined child applications.

### Applications Directory

The `components/talos-cluster/manifests/apps` directory contains all the child application definitions. These can be organized either as subfolders (for applications with multiple resources) or as individual YAML files for simpler setups.

```plaintext
components/talos-cluster/manifests/apps/
├── app1/
│   └── app1.yaml
├── app2.yaml
├── app3/
│   ├── config.yaml
│   └── deployment.yaml
```

## Adding a New Application

To add a new application:

1. Create the Application Manifest:
    - Define your application's ArgoCD Application resource in a YAML file.
    - Add the YAML file to the `apps` directory or create a subfolder for the application if it includes multiple resources.
1. Sync the Root Application:
    - Sync the root-application.yaml in ArgoCD.
    - ArgoCD will automatically detect and deploy the new application.

## Conclusion

By using the app-of-apps pattern with ArgoCD, you can streamline application deployments and manage multiple applications with ease. The `components/talos-cluster/manifests/bootstrap/root-application.yaml` file acts as the central orchestrator, providing a scalable and modular approach to Kubernetes application management.
