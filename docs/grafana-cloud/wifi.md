# Wi-Fi Dashboard

The dashboard "Network / Wi-Fi" shows the Wi-Fi link quality of the homelab nodes, so a Wi-Fi drop can be read against the signal strength and the link errors at that time. It shows the `node_wifi_*` series that the node_exporter `wifi` collector in the homelab Alloy config sends (see the [Alloy role](../homelab/ansible/roles/grafana-cloud/alloy.md), section "Wi-Fi Metrics"). Cloud droplets do not send them.

## Where It Lives

| File                                                                         | What it is                                                 |
|------------------------------------------------------------------------------|------------------------------------------------------------|
| `grafana-cloud/manifests/git-sync/homelab-infrastructure/network-wi-fi.json` | The dashboard (schema `dashboard.grafana.app/v2`, `wi-fi`) |

The dashboard is in the Grafana folder `homelab-infrastructure`, next to "Network / FRITZ!Box / Status". It has no folder of its own: Grafana Cloud Free allows 20 Git Sync resources and folders count, so a `network` folder was left out. With this dashboard, Git Sync holds 12 resources (2 folders, 10 dashboards).

The manifest was written by hand. It reaches Grafana Cloud through Git Sync once the commit lands on `main`, the branch Git Sync reads; a change on a feature branch shows up only after the merge. Edits made later in the Grafana Cloud UI are written back to this file by Git Sync (see `grafana-cloud/manifests/git-sync/README.md`), which may also rewrite IDs or the formatting on its first sync.

## Node Variable

The variable "Node" (`instance`) offers every node with `environment="homelab"` that has a `wl*` interface in `node_network_info` (every Wi-Fi interface in the fleet is named `wl*`: `wlan0`, `wlo1`, `wlp9s0`). That series exists independent of the connection, so a node is also offered while it is disconnected. A node without a Wi-Fi interface is not offered. A node with an unused Wi-Fi card (on Ethernet) is offered too, and its panels show "No data". Several nodes or "All" can be selected; every panel then has one line per node and interface.

## Rows

| Row        | Panel             | Shows                                                                                                         |
|------------|-------------------|---------------------------------------------------------------------------------------------------------------|
| Connection | Connection        | Per node and interface at the end of the time range: SSID, BSSID, channel frequency, time connected           |
| Connection | Reconnects        | Restarts of the connection time in the selected time range                                                    |
| Connection | Connected time    | Time connected to the current access point; a drop to 0 is a reconnect                                        |
| Signal     | Signal strength   | Signal strength in dBm, with lines at -60 (good), -70 (fair) and -80 dBm (weak below)                         |
| Throughput | Receive bitrate   | Link bitrate of received frames, the rate negotiated with the access point, not the traffic volume            |
| Throughput | Transmit bitrate  | Link bitrate of transmitted frames                                                                            |
| Errors     | Transmit retries  | Frames sent again, per second                                                                                 |
| Errors     | Transmit failures | Frames not delivered after all retries, per second                                                            |
| Errors     | Beacon loss       | Beacons from the access point the node missed, per second                                                     |

Reconnects are counted as resets of `node_wifi_station_connected_seconds_total`, which restarts at 0 on every new association, so no extra metric is needed. A reconnect, a node reboot, a Wi-Fi driver reload and a return to an access point used earlier in the range all count. A switch to a new access point starts a new series instead and is not counted, and a drop still ongoing at the end of the range is not counted either. The Connection table shows the state at the end of the time range: a node disconnected at that time is not listed, and after a roam the previous access point is gone with the next scrape, because Alloy marks the old series as stale. Very short drops between two scrapes can be missed, when the new connection is already longer at the next scrape than the old one was at the last scrape before the drop; they show only as a dip in "Connected time", if at all.

While a node is disconnected, its station series stop. The panels then show a gap, not zeros.

## Roaming

Every station series carries the label `mac_address`, the access point the node is connected to. When a node roams to another access point, its series continue under a new `mac_address`. Every query on a station metric therefore aggregates `by (instance, device)` (`max` for gauges, `sum` of `rate` for counters), so the lines of a node continue across a roam instead of splitting per access point. Every query also filters `environment="homelab"`.
