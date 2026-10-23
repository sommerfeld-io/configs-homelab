---
title: 'Story 9.1: Enable the Wi-Fi collector in the homelab Alloy config'
type: 'feature'
created: '2026-10-23'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No homelab node sends Wi-Fi metrics to Grafana Cloud, because the node_exporter `wifi` collector is off by default and the homelab Alloy config does not enable it. A Wi-Fi drop on pi4-0002 cannot be read against signal strength or link quality.

**Approach:** Enable the `wifi` collector in `prometheus.exporter.unix "integrations_node_exporter"` of the homelab template `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2` only, document it in the Alloy role README, and have the operator roll it out with `grafana-agents.yml`. Then confirm per Wi-Fi node that `node_wifi_*` series arrive. Nothing under `configs-cloud/` changes.

</frozen-after-approval>

## Implementation Notes

### Investigation (2026-10-23)

- `alloy validate` (v1.16.0 and v1.21.0) exits 0 for an unknown collector name (`wifix`), and `alloy run` silently skips it. `task lint` therefore does not prove the collector is on; the runtime check below does.
- `alloy run` v1.16.0 (oldest Alloy in the fleet, on caprica) in an unprivileged container without Wi-Fi logs `collector=wifi` at info level and exposes `node_scrape_collector_success{collector="wifi"} 1` with no `node_wifi_*` series: a node without Wi-Fi scrapes without a collector error.
- Read-only SSH as `sebastian` works to the fleet. Nodes with a Wi-Fi interface that is up: pi4-0002 (`wlan0`, Alloy v1.19.2), pi5-0004 (`wlan0`, v1.19.2), caprica (`wlo1`, v1.16.0), picon (`wlp9s0`, v1.20.1). pi4-0005, pi4-0006 and kobol do not resolve from the devcontainer.
- `iw` is not installed on the Pis or caprica. On picon, `iw dev wlp9s0 station dump` as the unprivileged `sebastian` returns signal, bitrates, retries, failures and beacon loss, so nl80211 station data needs no extra capability for the `alloy` user.
- `node_scrape_collector_.+` is dropped before remote write, so collector success is checked on each node's local endpoint `localhost:12345/api/v0/component/prometheus.exporter.unix.integrations_node_exporter/metrics`, not in Grafana Cloud.

### Plan

- `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2`: add `enable_collectors = ["wifi"]` above `disable_collectors`.
- `configs-homelab/ansible/roles/grafana-cloud/alloy/README.md`: a Wi-Fi section naming the collector, its metrics, the no-`iw`/`wireless-tools` note and that nodes without Wi-Fi report nothing; regenerate `docs/homelab/ansible/roles/grafana-cloud/alloy.md` with `task docs:generate`.
- Verify: `task lint`; `alloy run` with the rendered node exporter block; after the operator rollout, per-node check over SSH of `node_wifi_*` and `node_scrape_collector_success{collector="wifi"}`.

### Implementation

- Changed `config.alloy.j2` (one line, `enable_collectors  = ["wifi"]`), the Alloy role `README.md` (new section "Wi-Fi Metrics" with the metric table and the on-node check), and the generated copy `docs/homelab/ansible/roles/grafana-cloud/alloy.md` (`task docs:generate`). Nothing under `configs-cloud/`.
- The metric names in the README table were checked against the strings in the Alloy v1.16.0 binary (`station_signal_dbm`, `station_beacon_loss_total`, `interface_frequency_hertz`, ...); the rollout check confirms them on real nodes.
- `task lint` passed (exit 0, only the existing yamllint warnings). `lint-alloy-config` and `lint-markdown-links` passed again after the re-apply.
- Surprise: during implementation the user committed `6813c9f style: rename dashboard` on this branch, and the working tree briefly reverted these edits while that happened. The edits were re-applied. The unstaged deletion of `grafana-cloud/manifests/git-sync/homelab-infrastructure/fritz-box-status.json` belongs to the user and is not part of this story's commit.

## Acceptance Check

Against the Story 9.1 ACs in `epics.md`:

- AC 1 (template, lint, no `configs-cloud/` change): met. One line in the fleet template; `task lint` exit 0; `git diff --stat` lists no file under `configs-cloud/`.
- AC 3 (README): met. "Wi-Fi Metrics" in the Alloy role README names the collector, its metrics and labels, says no `iw`/`wireless-tools` is needed; copied by `task docs:generate`.
- AC 2 (fleet data): open until the operator runs `grafana-agents.yml`. Then, per node over read-only SSH, the `curl` from the README; for nodes that do not resolve from the devcontainer, `count by (instance, device) (node_wifi_station_info)` in Grafana Cloud. Results:

| Node     | Interface | Alloy   | Collector success | `node_wifi_*` | Missing station metrics |
|----------|-----------|---------|-------------------|---------------|-------------------------|
| pi4-0002 | `wlan0`   | v1.19.2 | pending rollout   | pending       | pending                 |
| pi5-0004 | `wlan0`   | v1.19.2 | pending rollout   | pending       | pending                 |
| caprica  | `wlo1`    | v1.16.0 | pending rollout   | pending       | pending                 |
| picon    | `wlp9s0`  | v1.20.1 | pending rollout   | pending       | pending                 |
| pi4-0005 | unknown   | unknown | not resolvable    | pending       | pending                 |
| pi4-0006 | unknown   | unknown | not resolvable    | pending       | pending                 |
| kobol    | unknown   | unknown | not resolvable    | pending       | pending                 |

## Review Triage Log

Blind Hunter, pass 1 (10 findings):

- medium, patched: "success 1" check wrong for nodes without nl80211. Upstream `collector/wifi_linux.go` returns `ErrNoData` on `os.ErrNotExist` and `os.ErrPermission`, and `collector.go` then sets `success = 0` with a debug log. README now explains 1, 0 and the `collector failed` error log.
- medium, patched: station series carry `mac_address` (upstream `wifiLabels = device, mac_address`), which changes on roaming. README documents it; matters for 9.2 queries.
- low, patched: table extended with `node_wifi_station_connected_seconds_total` (the reviewer's `connected_time_seconds` name is wrong; the binary and source have `station_connected_seconds_total`). Names are confirmed on real nodes in the Acceptance Check.
- medium, deferred: no automated guard for the collector line (`deferred-work.md`); a CI or lint check is outside this story and fits Epic 6.
- maybe-false, patched by rewording: "the `alloy` user needs no extra capability" was shown only on picon with `iw`, and the fleet override already grants capabilities. README now says "the role needs no change"; `ErrPermission` would show as success 0 in the rollout check.
- low, patched: the `iw`/`wireless-tools` hint now quotes "no supported wireless tool installed" from the pi4-0002 investigation.
- medium, patched: spec had no acceptance check or per-node results; added above (AGENTS.md pitfall on own acceptance check).
- low, patched: README notes that SSID and BSSID go to Grafana Cloud as labels; keeping them is the story's intent (9.2 panel).
- low, patched: `epic-9-context.md` now says "every homelab node with a Wi-Fi interface". Rejected the CLAUDE.md inventory-groups part: CLAUDE.md lists example groups, `grafana-agents.yml` is authoritative.
- low, patched: `sprint-status.yaml` gets a gate comment for 9.1 like 9.2's.
