# Grafana Cloud Manifests - Unsynced

This directory holds exports of Grafana Cloud objects that, as of 2026-09-21, cannot be provisioned through Grafana Cloud's Git Sync integration (e.g. alerts). These objects were set up manually in the Grafana Cloud UI and are kept here only as a manual, version-controlled backup.

As soon as Grafana Cloud's Git Sync supports the respective object type, it should be moved into [`git-sync/`](../git-sync/README.md) and managed the same way as dashboards.

Using Terraform / OpenTofu is deliberately not an option here: it would require managing state, and Terraform / OpenTofu is not used anywhere else in this repository. This directory exists specifically to avoid introducing it just for this gap.
