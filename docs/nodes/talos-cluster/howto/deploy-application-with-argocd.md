# How to deploy an Application with ArgoCD

This guide explains how to deploy applications into the Talos Cluster with ArgoCD using the [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#app-of-apps) pattern.

## The App-of-Apps Pattern

The App of Apps pattern is a strategy where a single ArgoCD Application resource manages other Application resources. This approach allows you to organize and deploy multiple applications efficiently. By using a parent application to define and synchronize other applications, you achieve a hierarchical structure that simplifies management and scalability. Each child application can reside in its own folder or YAML file, making it modular and easier to maintain.

- **Centralized Management:** The parent application acts as a single point of control for all child applications.
- **Modularity:** Each application can be managed independently, allowing for granular updates and configurations.
- **Scalability:** Easily add or remove applications without impacting the parent configuration.
- **Clarity:** The folder structure provides clear organization of applications.

## Configuration Overview

In this setup, the `components/talos-cluster/manifests/projects/app-of-apps.yaml` file is the key to establishing the app-of-apps pattern. This file was set up by the ArgoCD Autopilot and now also contains the config to define the parent application, which manages all child applications located within the `components/talos-cluster/manifests/apps` directory. All apps from this directory are synchronized automatically.

### Root Application

The `components/talos-cluster/manifests/projects/app-of-apps.yaml` file is the entry point for the App of Apps pattern. It specifies the child applications by pointing to their manifests within the `apps` directory. When ArgoCD syncs this root application, it automatically discovers and applies the configurations of all defined child applications.

### Applications Directory

The `components/talos-cluster/manifests/apps` directory contains all the child application definitions. These are organized sub-folders. The folder name will be used as the namespace for the application. Each application can have one or more YAML files that define the resources to deploy.

```plaintext
components/talos-cluster/manifests/apps/
├── app1/
│   └── app1.yaml
├── app2/
│   ├── config.yaml
│   └── deployment.yaml
```

## Adding a New Application

- [ ] Define your application's ArgoCD Application resource in YAML file(s).
- [ ] Add the YAML file to the `apps` directory or create a subfolder for the application if it includes multiple resources.
- [ ] There is no need to define a dedicated ArgoCD `Application` resource for the application in the `apps` directory because the `app-of-apps` `ApplicationSet` from `components/talos-cluster/manifests/projects/app-of-apps.yaml` will automatically create the `Application` resource.
- [ ] There is no need to define a dedicated namespace for the application in the `apps` directory because the `app-of-apps` `ApplicationSet` from `components/talos-cluster/manifests/projects/app-of-apps.yaml` will automatically create the namespace for the application based on the folder name.
- [ ] ArgoCD will automatically detect and deploy the new application.

## Conclusion

By using the App of Apps pattern with ArgoCD, you can streamline application deployments and manage multiple applications with ease. The `components/talos-cluster/manifests/projects/app-of-apps.yaml` file acts as the central orchestrator, providing a scalable and modular approach to Kubernetes application management.
