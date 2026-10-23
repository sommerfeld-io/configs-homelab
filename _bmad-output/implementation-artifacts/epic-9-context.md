# Epic 9 Context: Wi-Fi telemetry for homelab nodes

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make Wi-Fi drops on homelab nodes correlatable with signal strength and link quality in Grafana Cloud. A Grafana Cloud investigation of unstable Wi-Fi on pi4-0002 (2026-10-22) found no Wi-Fi metrics at all: the node_exporter `wifi` collector is not enabled in the homelab Alloy config. This epic enables that collector for every homelab node (desktops, servers, Raspberry Pis) and adds a "Wi-Fi" dashboard, so a connection drop can be read against the link quality at that time. It is homelab-only, was added after Epic 8, and runs before Epic 6.

## Stories

- Story 9.1: Enable the Wi-Fi collector in the homelab Alloy config
- Story 9.2: Wi-Fi dashboard in the Git Sync folder network

## Requirements & Constraints

- Every homelab node with a Wi-Fi interface reports Wi-Fi interface and station metrics (signal strength, receive/transmit bitrates, retries, failures) to Grafana Cloud through the node_exporter `wifi` collector in its Alloy config.
- Nothing under `configs-cloud/` changes. Droplets are VMs, and whether their uplink is wireless does not matter. `git diff` over the whole epic must show no file under `configs-cloud/`.
- On a Wi-Fi node (pi4-0002 is the reference), `node_wifi_station_signal_dbm` and the other `node_wifi_*` series for its interface must appear in Grafana Cloud after the rollout. Every node with a Wi-Fi interface is listed with its result. Nodes without Wi-Fi must still scrape without collector errors.
- Residual risk: the Raspberry Pi Wi-Fi driver might not report every station metric. Record what each node actually delivers.
- The dashboard "Network / Wi-Fi" lives in the existing Git Sync folder `homelab-infrastructure`, next to "Network / FRITZ!Box / Status", and shows per node and interface: signal strength (dBm), receive and transmit bitrate, transmit retries and failures, beacon loss, connected SSID/BSSID, plus a node variable.
- Grafana Cloud Free allows 20 Git Sync resources, and folders count. Today there are 11 (2 folders, 9 dashboards). The Wi-Fi dashboard makes 12 (2 folders, 10 dashboards). A `network` folder was removed before for this limit, so no new folder is created (user decision 2026-10-23, option B).
- `task lint` must pass, including `lint-alloy-config`, which validates the homelab template.
- Docs: the Alloy role README says which collector is on, which metrics it gives, and that no `iw` or `wireless-tools` package is needed. Edit the README, not the copy that `task docs:generate` makes. The dashboard is documented next to the other Grafana Cloud docs.

## Technical Decisions

- **One template change.** The collector is enabled in `prometheus.exporter.unix "integrations_node_exporter"` in the homelab template `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2`, which today only sets `disable_collectors`. The `configs-cloud` templates are not touched.
- **The cloud is isolated by design.** The droplet uses its own Alloy template through `alloy_config_template`, so a change to the homelab template does not reach `configs-cloud`.
- **No extra packages.** Alloy's `wifi` collector reads nl80211 through netlink. The "no supported wireless tool installed" log message and the Grafana Cloud hint to install `iw`/`wireless-tools` do not apply. The collector is off by default upstream, read-only, and returns no data on nodes without Wi-Fi.
- **Rollout path.** The operator runs `grafana-agents.yml` (vault password), which covers `ubuntu_desktop`, `ubuntu_server`, `raspi` and `omarchy`. The Alloy handler restarts the service.
- **Not needed:** no new role, so no Molecule scenario, and no CI change. The existing architecture decisions already cover the change: Ansible is the source of truth, and this repo's CI lints and validates but never applies fleet playbooks.
- **Out of scope:** the unmerged branch `fix/wifi-powersave-raspi` (turns off Wi-Fi power save on the Pis) is a separate change. Epic 9 makes its effect measurable.

## Cross-Story Dependencies

- Story 9.2 needs live `node_wifi_*` series from Story 9.1, so 9.1 must be rolled out and verified on pi4-0002 first.
- The operator runs the rollout for 9.1 and confirms data from pi4-0002.
- Story 9.2 stays in `review` until the dashboard is merged to `main` and Git Sync has been observed to show it in the folder `homelab-infrastructure` with data from pi4-0002. Never mark it `done` before that.
- Epic 6 starts after this epic. The open Epic 8 retro items are independent of it.
