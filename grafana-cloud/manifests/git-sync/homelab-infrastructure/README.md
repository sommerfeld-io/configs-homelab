# Grafana Cloud Manifests - Homelab Infrastructure

This directory is the Grafana Cloud folder `homelab-infrastructure`. It holds the dashboards for the homelab nodes, the containers running on them and the network.

The network dashboards are "Network / FRITZ!Box / Status" (`network-fritz-box-status.json`) and "Network / Wi-Fi" (`network-wi-fi.json`), which shows the Wi-Fi link quality of every homelab node with a Wi-Fi interface. The Wi-Fi dashboard was written by hand into this folder and is documented in `docs/grafana-cloud/wifi.md`.

Like everything in [`git-sync/`](../README.md), the dashboard manifests are owned by Grafana Cloud's Git Sync.
