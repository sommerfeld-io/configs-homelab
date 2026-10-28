---
title: 'Epic 9 retro item 45: keep sending the Wi-Fi SSID, BSSID and mac_address labels to Grafana Cloud'
type: 'chore'
created: '2026-10-28'
status: 'done'
baseline_commit: '0e79a23ea726847e6850c46382f11b08c8c88b86'
route: 'oneshot'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-9-retro-2026-10-23.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 9 retro action item 45 (finding C3, action A5) left open whether the Wi-Fi labels `ssid`, `bssid` and `mac_address` keep going to Grafana Cloud, or are dropped or hashed in `prometheus.relabel "integrations_node_exporter"`. The open decision is also logged in `deferred-work.md`.

**Approach:** The user decided on 2026-10-28: keep sending SSID, BSSID, `mac_address` etc. to Grafana Cloud, do not drop or hash anything. No change to the Alloy config. Record the decision in the Alloy role README (and its docs copy), delete the resolved `deferred-work.md` entry, and mark item 45 `done` in `sprint-status.yaml`.

</frozen-after-approval>

## Implementation Notes

- `configs-homelab/ansible/roles/grafana-cloud/alloy/README.md` "Wi-Fi Metrics": the labels sentence now says they are sent on purpose, that the relabel block neither drops nor hashes them, that the Network / Wi-Fi dashboard shows SSID and BSSID, and that a roam starts new station series. `docs/homelab/ansible/roles/grafana-cloud/alloy.md` carries the same text; `task docs:generate` exit 0 with no further diff.
- Checked `config.alloy.j2` lines 81-89: `prometheus.relabel "integrations_node_exporter"` only drops `node_scrape_collector_.+`, so no config change is needed.
- `deferred-work.md`: the spec-9-1 decision entry deleted. `sprint-status.yaml`: item 45 `done`. `epic-9-retro-2026-10-23.md` Follow-Up: 2026-10-28 entry for A5/C3 (added after review).
- `task lint` exit 0.

## Review Triage Log

Blind Hunter, 7 findings:

- false — spec still `in-progress` with empty notes: review ran before the finalize step, which sets `done` and fills the notes.
- low, patch — retro Follow-Up did not record that A5/C3 was decided; 2026-10-28 entry added.
- medium, patch — the README gave no reason for keeping the labels; it now names the factual dependency (the Network / Wi-Fi dashboard shows SSID and BSSID). No privacy or series-cost reasoning added, since the user gave none.
- low, patch — the roam sentence named only `mac_address`; `node_wifi_station_info` also changes `bssid`, now named. The series-cost aside is not added (no user reasoning to record).
- low, patch — "Epic 9 retro item 45" in the published docs page; no other role README cites tracker items, so it was dropped.
- low, reject — a comment in the relabel block marking the choice: the README already records it and the spec rules out Alloy config changes.
- low, reject — spec `context` list incomplete: the Approach names every file touched.
