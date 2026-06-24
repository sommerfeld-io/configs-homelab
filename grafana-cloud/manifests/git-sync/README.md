# Grafana Cloud Manifests

This directory contains dashboard and configuration manifests managed by Grafana Cloud's Git Sync integration. Grafana Cloud uses this location to store dashboard JSON definitions, folder structures, and other configuration as code - allowing the state of the Grafana Cloud organization to be version-controlled, auditable, and reproducible from this repository.

The `git-sync/` subdirectory is the designated sync target configured in Grafana Cloud. Whenever a dashboard is created, updated, or deleted in the Grafana Cloud UI, the corresponding JSON manifest in this directory is automatically updated by Grafana. This makes every change traceable through git history, and enables the Grafana configuration to be treated as infrastructure code alongside the rest of this homelab's configuration.

**Do not manually edit files inside `git-sync/`.** All changes to dashboards and related configuration must be made through the Grafana Cloud UI. Grafana owns this directory and any manual edits will be overwritten or may cause sync conflicts. Treat this folder as read-only from the perspective of human contributors.
