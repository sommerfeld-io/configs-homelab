---
date: 2026-10-22
trigger: grafana-investigation-pi4-0002-wifi
mode: incremental
scope: moderate
status: approved
approved: 2026-10-22
---

# Sprint Change Proposal: Wi-Fi Telemetry for Homelab Nodes Before Epic 6

## 1. Issue Summary

A Grafana Cloud investigation looked into unstable Wi-Fi connections between pi4-0002 and the router, and found:

- no Wi-Fi signal or link-quality metrics exist;
- the node_exporter `wifi` collector is not enabled;
- the host logs "no supported wireless tool installed".

Without those metrics, a connection drop cannot be correlated with signal strength. Grafana Cloud recommends enabling the node_exporter `wifi` collector, or installing `iw`/`wireless-tools`.

- **Type:** new requirement from the operator.
- **Discovered:** on 2026-10-22, in a Grafana Cloud investigation of pi4-0002, after Epic 8 and before Epic 6.
- **Decisions by the operator:**
    - Enable the `wifi` collector for every homelab node (desktops, servers, Raspberry Pis).
    - Add a Wi-Fi dashboard in `grafana-cloud/manifests/git-sync/network`.
    - Limit the change to `configs-homelab`. Nothing under `configs-cloud/` changes: for droplets, which are VMs in the cloud, it does not matter whether they use Wi-Fi or cable, as long as they are fast enough.
    - Run the new epic after Epic 8 and before Epic 6.

**Evidence checked on 2026-10-22:**

- **The template does not enable the collector:** the homelab template `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2:57-58` sets only `disable_collectors`.
- **Alloy has the collector:** `grafana/alloy:v1.20.1` with `enable_collectors = ["wifi"]` logs `collector … name=wifi`. The collector reads nl80211 through netlink and needs no `iw` or `wireless-tools`. Whether it delivers station data on pi4-0002 is verified in Story 9.1.
- **The cloud stays untouched:** the droplet uses its own template through `alloy_config_template` (`configs-cloud/digital-ocean/ansible/vars/main.yml:10`), so a change to the homelab template does not reach `configs-cloud`.
- **The rollout reaches all homelab node groups:** `grafana-agents.yml` rolls Alloy out to `ubuntu_desktop`, `ubuntu_server`, `raspi` and `omarchy`.
- **The `network` folder was removed before:** commit `3f191cc` removed it to stay under the Grafana Cloud Free limit of 20 Git Sync resources (folders count). Today there are 11 resources: 2 folders and 9 dashboards. A `network` folder with one dashboard makes 13.

## 2. Impact Analysis

### Epic Impact

| Epic       | Impact                                                                                                                                   |
|------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Epic 1     | Done, unchanged.                                                                                                                         |
| Epics 2-8  | Done (Epic 8 retro done), unchanged. Open Epic 8 retro items 36 to 38 are independent of this change.                                    |
| Epic 9     | **New** homelab epic in `epics.md`: Wi-Fi telemetry for homelab nodes. Runs after Epic 8 and before Epic 6.                              |
| Epic 6     | Unchanged; starts after Epic 9.                                                                                                          |

### Story Impact

- **New Story 9.1**, "Enable the Wi-Fi collector in the homelab Alloy config": the template change, the rollout by the operator, verification on pi4-0002 and the docs.
- **New Story 9.2**, "Wi-Fi dashboard in the Git Sync folder network": needs live `node_wifi_*` series from 9.1, and stays in `review` until Git Sync from `main` is observed.
- No existing story changes.

### Artifact Conflicts

| Artifact                                                        | Change                                                     |
|-----------------------------------------------------------------|------------------------------------------------------------|
| `prds/prd-configs-homelab-2026-08-24/prd.md`                    | New FR-10 in §4.3, §6.1 In Scope line, `updated`           |
| `specs/spec-configs-homelab/SPEC.md`                            | New CAP-10                                                 |
| `epics.md`                                                      | FR10, FR Coverage Map, Epic List entry, Epic 9 section     |
| `epics-fantasy-hockey-digitalocean.md`                          | One run-order sentence in the Overview                     |
| `implementation-artifacts/sprint-status.yaml`                   | `epic-9` block before `epic-6`                             |
| `ARCHITECTURE-SPINE.md`                                         | None: AD-1, AD-2 and AD-8 already cover the change         |
| UX                                                              | None: no UX artifacts exist                                |

### Technical Impact

- **Code:** one change in the homelab Alloy template. The `configs-cloud` templates are untouched.
- **Rollout:** the operator runs `grafana-agents.yml`. The Alloy handler restarts the service.
- **Checks:** the `lint-alloy-config` check (`task lint` and the CI lint matrix) validates the homelab template.
- **Grafana Cloud:** a new folder `network` and a dashboard, synced from `main`. The Git Sync count stays within the Free limit (13 of 20).
- **Not needed:** no new package, no Molecule scenario (no new role), no change to CI.

## 3. Recommended Approach

**Direct adjustment:** add a new epic within the existing structure.

- **Rollback:** not applicable.
- **MVP review:** not needed. FR-10 extends §4.3 Observability, and the MVP stays reachable.
- **Effort:** low. Two stories, one template change and one dashboard.
- **Risk:** low. The collector is off by default upstream and is read-only. On nodes without Wi-Fi it returns no data.
- **Residual risk:** the Raspberry Pi Wi-Fi driver might not report every station metric. Story 9.1 records what each node delivers.
- **Timeline:** Epic 6 starts after Epic 9.

The unmerged local branch `fix/wifi-powersave-raspi` turns off Wi-Fi power save on the Raspberry Pis. It may address the drops themselves, but it is a separate change and not part of this proposal. With Epic 9 in place, its effect becomes measurable.

## 4. Detailed Change Proposals

All five proposals were approved one by one in incremental mode on 2026-10-22.

### 4.1 PRD: New FR-10

`prds/prd-configs-homelab-2026-08-24/prd.md`, §4.3 Observability (Grafana Alloy), after FR-4:

```markdown
#### FR-10: Wi-Fi nodes report their wireless link quality

Every homelab node (desktops, servers, Raspberry Pis) reports Wi-Fi interface and station metrics (signal strength, link bitrates, retries and failures) to Grafana Cloud through the node_exporter wifi collector in its Alloy config, so a connection drop can be correlated with the link quality at that time. Cloud droplets are out of scope: whether a VM's uplink is wireless does not matter to the operator.

**Consequences (testable):**

- On a node that uses Wi-Fi (e.g. pi4-0002), `node_wifi_*` series for its interface appear in Grafana Cloud after `grafana-agents.yml` ran.
- A dashboard "Wi-Fi" in the Git Sync folder `network` shows these series per node.
- The Alloy configs of `configs-cloud` are unchanged.
```

§6.1 In Scope gets `- Wi-Fi link-quality telemetry for homelab nodes (FR-10)`. The frontmatter gets `updated: 2026-10-22`.

**Rationale:** FR-4 covers telemetry in general, and FR-10 makes the Wi-Fi signal an explicit, testable requirement.

### 4.2 SPEC: New CAP-10

`specs/spec-configs-homelab/SPEC.md`, `## Capabilities`, after CAP-9:

```markdown
- **CAP-10**
    - **intent:** Every homelab node reports its Wi-Fi link quality (signal strength, bitrates, retries, failures) to Grafana Cloud through the node_exporter wifi collector in its Alloy config. Cloud droplets are excluded.
    - **success:** On a Wi-Fi node (e.g. pi4-0002), `node_wifi_*` series appear in Grafana Cloud and the "Wi-Fi" dashboard in the Git Sync folder `network` shows them per node; the `configs-cloud` Alloy configs are unchanged.
```

**Rationale:** SPEC is the canonical contract that the build specs work from, and CAP-10 mirrors PRD FR-10.

### 4.3 Epics: FR10 and Epic 9

`epics.md` changes in four places.

**Functional Requirements**, after FR9:

```markdown
FR10: Every homelab node (desktops, servers, Raspberry Pis) reports its Wi-Fi link quality (signal strength, bitrates, retries, failures) to Grafana Cloud through the node_exporter wifi collector in its Alloy config, shown on a "Wi-Fi" dashboard; cloud droplets are excluded. (SPEC CAP-10 / PRD FR-10)
```

**FR Coverage Map**, after FR9:

```markdown
FR10: Epic 9 - Wi-Fi collector in the homelab Alloy config and the Wi-Fi dashboard
```

**Epic List**, after Epic 1:

```markdown
### Epic 9: Wi-Fi telemetry for homelab nodes
Wi-Fi drops on homelab nodes can be correlated with signal strength and link quality in Grafana Cloud. Homelab only: nothing under configs-cloud changes. Added 2026-10-22 (sprint-change-proposal-2026-10-22); runs after Epic 8 and before Epic 6 (epics-fantasy-hockey-digitalocean.md).
**FRs covered:** FR10
```

**New section** after Epic 1:

```markdown
## Epic 9: Wi-Fi telemetry for homelab nodes

### Story 9.1: Enable the Wi-Fi collector in the homelab Alloy config

As an operator,
I want every homelab node's Alloy to export Wi-Fi metrics,
So that a connection drop can be correlated with the link quality at that time.

**Acceptance Criteria:**

**Given** `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2`
**When** the change is made
**Then** `prometheus.exporter.unix "integrations_node_exporter"` enables the `wifi` collector, `task lint` passes (including `lint-alloy-config`), and nothing under `configs-cloud/` changes (the droplet keeps its own template)

**Given** `grafana-agents.yml` applied to the fleet (operator)
**When** Grafana Cloud is queried
**Then** pi4-0002 reports `node_wifi_station_signal_dbm` and the other `node_wifi_*` series for its Wi-Fi interface, every node that has a Wi-Fi interface is listed with its result, and nodes without Wi-Fi still scrape without collector errors

**Given** the change
**When** it is done
**Then** the Alloy role README (copied to docs by `task docs:generate`) says which collector is on, which metrics it gives, and that no `iw` or `wireless-tools` package is needed

### Story 9.2: Wi-Fi dashboard in the Git Sync folder network

As an operator,
I want a Wi-Fi dashboard in Grafana Cloud,
So that I see the link quality of every Wi-Fi node at a glance and next to its drops.

**Acceptance Criteria:**

**Given** the `node_wifi_*` series from Story 9.1
**When** the dashboard "Wi-Fi" is added as `grafana-cloud/manifests/git-sync/network/` (with `_folder.json`)
**Then** it shows per node and interface: signal strength (dBm), receive and transmit bitrate, transmit retries and failures, beacon loss, connected SSID/BSSID, and a node variable, and the Git Sync resource count stays within the Free plan limit of 20 (13 after this story)

**Given** the dashboard merged to `main`
**When** Git Sync has run
**Then** the dashboard is visible in Grafana Cloud under the folder `network` with data from pi4-0002; the story stays in `review` until this was observed (AGENTS.md pitfall)

**Given** the change
**When** it is done
**Then** the dashboard is documented next to the other Grafana Cloud docs
```

**Rationale:**

- `epics.md` owns the homelab FRs.
- Epic 9 continues the global epic numbering.
- There are two stories because the dashboard needs live metrics from 9.1 first.

### 4.4 Run-Order Note in the DigitalOcean Epics File

`epics-fantasy-hockey-digitalocean.md`, `## Overview`, after the sentence about Epic 8:

```markdown
Epic 9 (Wi-Fi telemetry for homelab nodes) is a homelab epic in `epics.md`, added on 2026-10-22; it also runs before Epic 6 and changes nothing in this file's scope.
```

**Rationale:** the AGENTS.md pitfall "update every planning doc in the same change". This is a planning doc; no file under `configs-cloud/` changes.

### 4.5 Sprint Status: The `epic-9` Block

`implementation-artifacts/sprint-status.yaml`, between `epic-8-retrospective` and `epic-6`, written with the comment-preserving YAML round trip:

```yaml
  # Epic 9 (homelab, epics.md) runs after Epic 8 and before Epic 6 (sprint-change-proposal-2026-10-22)
  epic-9: backlog
  9-1-enable-the-wi-fi-collector-in-the-homelab-alloy-config: backlog
  # 9.2 needs live node_wifi_* series from 9.1, and stays in review until Git Sync from main is observed
  9-2-wi-fi-dashboard-in-the-git-sync-folder-network: backlog
  epic-9-retrospective: optional
```

## 5. Implementation Handoff

**Scope: moderate.** A new epic with two stories, plus planning-doc updates across five artifacts. No replan is needed.

| Who                       | Responsibility                                                                                                         |
|---------------------------|------------------------------------------------------------------------------------------------------------------------|
| Correct Course (this run) | Apply the five approved edits to the planning artifacts and `sprint-status.yaml` after approval                        |
| Developer (`bmad-build`)  | Story 9.1, then Story 9.2, each in a fresh session                                                                     |
| Operator                  | Run `grafana-agents.yml` (vault password), confirm data from pi4-0002, merge 9.2 to `main` and observe Git Sync        |

**Success criteria:**

- `node_wifi_station_signal_dbm` from pi4-0002 is visible in Grafana Cloud.
- The "Wi-Fi" dashboard is in the folder `network` and shows data per node.
- `git diff` over Epic 9 shows no file under `configs-cloud/`.
- `task lint` passes.
