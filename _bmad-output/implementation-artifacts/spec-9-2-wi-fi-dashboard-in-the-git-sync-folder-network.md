---
title: 'Story 9.2: Wi-Fi dashboard in the Git Sync folder network'
type: 'feature'
created: '2026-10-23'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '82fd90299f446791fd254b25514a17aaa549b646'
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Since Story 9.1 the Wi-Fi nodes send `node_wifi_*` series, but no dashboard shows them, so a Wi-Fi drop cannot be read against the link quality at a glance.

**Approach:** One hand-written v2 dashboard "Network / Wi-Fi" in the existing Git Sync folder `homelab-infrastructure`, reaching Grafana Cloud when merged to `main`, with a node variable and per node and interface: signal strength (dBm), receive and transmit bitrate, transmit retries and failures, beacon loss, connected SSID/BSSID. Documented next to the other Grafana Cloud docs.

**Decision (user, 2026-10-23):** option B. The dashboard goes into `homelab-infrastructure` next to "Network / FRITZ!Box / Status", titled "Network / Wi-Fi"; no new folder `network`, so Git Sync has 12 resources instead of the 13 the AC names.

## Boundaries & Constraints

**Always:** Every query filters `environment="homelab"` and aggregates station series `by (instance, device)`, because `mac_address` changes when a node roams to another access point. Git Sync stays within the Free plan limit of 20 resources; no new folder. The story stays in `review` until the dashboard is seen in Grafana Cloud with data from pi4-0002 after Git Sync from `main`.

**Never:** No change to existing dashboards (including the user's `network-fritz-box-status.json`), no alert rules, no Alloy change, no edits through the Grafana Cloud UI or API by the agent, nothing under `configs-cloud/`.

## I/O & Edge-Case Matrix

| Scenario       | Input / State                                    | Expected Output / Behavior                                         | Error Handling                |
|----------------|--------------------------------------------------|--------------------------------------------------------------------|-------------------------------|
| Normal         | pi4-0002 selected, connected                     | One line per interface in every panel; SSID/BSSID in the table     | N/A                           |
| Roaming        | Node switches access point in the time range     | Signal and rate lines continue, not split per access point; BSSID table shows the current one | N/A                           |
| No Wi-Fi node  | Node without `node_wifi_*` series                | Not offered in the node variable                                   | N/A                           |
| Disconnected   | Station series stop during a drop                | Gap in the lines; reconnect count rises                            | Panels show gaps, not zeros   |

</frozen-after-approval>

## Code Map

- `grafana-cloud/manifests/git-sync/homelab-infrastructure/docker-containers-by-node.json` -- v2 shape to copy: top-level `spec` keys, `QueryVariable` `instance` with label, `RowsLayout` with `GridLayout` rows, `Panel`/`QueryGroup` with datasource `grafanacloud-prom`, `timeSettings`.
- `grafana-cloud/manifests/git-sync/*/README.md` -- each folder has a short README naming its dashboards.
- `docs/grafana-cloud/synthetic-monitoring.md`, `mkdocs.yml` nav "Grafana Cloud" -- where the dashboard doc goes.
- `configs-homelab/ansible/roles/grafana-cloud/alloy/README.md` "Wi-Fi Metrics" -- metric names and labels (`device`, `mac_address`; `node_wifi_station_info` has `ssid`, `bssid`, `mode`).
- Resource count today: 2 folders + 9 dashboards = 11.

## Tasks & Acceptance

**Execution:**
- [x] `grafana-cloud/manifests/git-sync/homelab-infrastructure/README.md` -- name the Wi-Fi dashboard among the network dashboards -- folder README.
- [x] `grafana-cloud/manifests/git-sync/homelab-infrastructure/network-wi-fi.json` -- v2 dashboard titled "Network / Wi-Fi" (file name follows `network-fritz-box-status.json`), `metadata.name` `wi-fi`, tags `network`, `wifi`; variable `instance` (label "Node", multi, All, from `label_values(node_wifi_station_info{environment="homelab"}, instance)`); rows: Connection (table of SSID, BSSID, interface, frequency per node; connected time; reconnects from `resets(node_wifi_station_connected_seconds_total)`), Signal (signal dBm with thresholds), Throughput (receive and transmit bitrate), Errors (rate of transmit retries, transmit failures, beacon loss) -- the dashboard.
- [x] `docs/grafana-cloud/wifi.md`, `mkdocs.yml` -- page "Wi-Fi Dashboard": where it lives, what each row shows, the roaming aggregation, that it arrives through Git Sync from `main` -- docs AC.
- [x] `_bmad-output/planning-artifacts/epics.md`, `_bmad-output/implementation-artifacts/epic-9-context.md` -- Story 9.2 AC and constraints: folder `homelab-infrastructure`, title "Network / Wi-Fi", 12 resources instead of folder `network` and 13 (AGENTS.md: update every planning doc when a decision changes a planning fact) -- planning docs match the decision.
- [x] Check script over the manifest -- every query has `environment="homelab"` and `by (instance, device)` on station metrics; JSON parses; resource count.

**Acceptance Criteria:**
- Given the branch, when `task lint` runs, then it passes and Git Sync has 12 resources (2 folders, 10 dashboards).
- Given the merge to `main` and a Git Sync run, when the user opens "Wi-Fi" with pi4-0002, then every panel shows data (user check; story stays in `review` until then).

## Spec Change Log

## Design Notes

Reconnects come from counter resets of `node_wifi_station_connected_seconds_total`, which restarts at 0 on every new association; this puts drops next to the link quality without a new metric.

## Verification

**Commands:**
- `task lint` -- expected: exit 0
- `python3` check over the manifest -- expected: every expr filters `environment="homelab"`
- After the rollout: compare every metric and label name in the manifest with the per-node `curl` output from Story 9.1 -- expected: all present on pi4-0002

## Implementation Notes

- Built by the step-03 implementation subagent from this spec. Files: `homelab-infrastructure/network-wi-fi.json` (new, generated by a scratch script, 9 panels in 4 rows), the folder `README.md`, `docs/grafana-cloud/wifi.md` (new), `mkdocs.yml`, and the Story 9.2 wording in `epics.md` and `epic-9-context.md`. Beyond the task list, the subagent also updated the one matching line in `prds/prd-configs-homelab-2026-08-24/prd.md` and `specs/spec-configs-homelab/SPEC.md` (AGENTS.md rule on planning facts); kept. `sprint-change-proposal-2026-10-22.md` keeps "network" as the record of the original proposal.
- Verification: `task lint` exit 0; check script (JSON parses, 11 queries plus the variable filter `environment="homelab"`, station queries `by (instance, device`, 12 Git Sync resources in the working tree); `promtool check rules` on all expressions; markdownlint 0 errors; docs build OK.
- Matrix audit: no test framework applies to dashboard JSON. Structural parts are checked by the script (no zero-fill, aggregation per node and interface, variable from `node_wifi_station_info`). The data-dependent rows (Normal, Roaming, Disconnected) need live series and are part of the user check after Git Sync.
- Open: Story 9.1 is not live on any Wi-Fi node yet (checked 2026-10-23 17:56 UTC), so names are not yet compared against a real scrape. The 12-resource count assumes the user's unstaged deletion of `fritz-box-status.json` is committed; otherwise 13.

## Review Triage Log

Pass 1: Blind Hunter (13), Edge Case Hunter (6), Verification Gap (1 gap plus 3 other findings). Duplicates are merged into one row and named by their sources.

- medium, patched (ECH 3, BH 8): the node variable from `node_wifi_station_info` hid a Wi-Fi node that was disconnected for the whole range. It now comes from `node_network_info{device=~"wl.+"}`, and every Wi-Fi interface in the fleet is `wl*` (checked over SSH on pi4-0002, caprica, picon).
- low, patched (ECH 4, BH 7): "After roaming, only the current access point is listed" was false within the 5-minute lookback; the panel description and the doc were reworded.
- low, patched (ECH 2, BH 11 part): `resets()` misses drops shorter than a scrape; this is now stated in the panel and the doc. The other part of BH 11 was rejected: the Connected time panel already shows each drop over time, next to the other panels.
- medium, user action (VG other, ECH 5, ECH 6, BH 2): HEAD has two dashboards with `metadata.name` `000000013` from `6813c9f`; the "12 resources" claim holds only with the user's uncommitted deletion of `fritz-box-status.json`. That file is the user's, so it is not part of this commit; it was raised with the user.
- medium, deferred (VG gap): no lint or CI check over the Git Sync manifests (parse, unique name, count). The gap predates this story (Story 5.1 triage row 1); recorded in `deferred-work.md`.
- medium, deferred (BH 1): the README "do not manually edit" rule conflicts with hand-written manifests. The conflict predates this story (5.1 row 12) and the rule is the user's; recorded in `deferred-work.md`.
- maybe-false, rejected (ECH 1, BH 6): threshold base step `0` above the -80/-70/-60 steps. Grafana treats the first step as the base regardless of its value, and the exported sibling manifests write the base as `0`. Wrong colours would only be low, and the user check after Git Sync shows them.
- false (BH 3): 9.2 `in-progress` before 9.1 was verified. The user asked for both stories in succession; the live-data checks are listed as open in Implementation Notes.
- false (BH 4): a missing driver metric shows "No data", which Grafana renders differently from a flat 0 line. The per-node results of 9.1 will record what each driver delivers.
- low, rejected (BH 5): the sprint key and spec file name still say `network`. Renaming the key breaks the tracking tooling, and the spec records the decision.
- low, rejected (BH 9): no dashboard links to the node overview or FRITZ!Box. Not in the ACs; a nice-to-have.
- false (BH 10): the hard-coded `grafanacloud-prom` matches `docker-containers-by-node.json` in the same folder.
- false (BH 12): validation is recorded in Implementation Notes (`task lint`, check script, promtool, markdownlint, docs build).
- low, rejected (BH 13): code spans for paths outside `docs/` follow the docs convention, the count repeated across planning docs follows the AGENTS.md rule, and the `cps` unit is cosmetic.

### Review Findings

Code review of Epic 9 (Stories 9.1 and 9.2, `origin/main...feat/epic-9`), 2026-10-23: Blind Hunter, Edge Case Hunter, Verification Gap and Acceptance Auditor. The user asked for every finding to be fixed right away or deferred, so there are no decision items.

- [x] [Review][Patch] "For up to 5 minutes after a roam the previous access point can still be listed" is wrong: Alloy's scrape writes staleness markers, so the old series ends at the next scrape [grafana-cloud/manifests/git-sync/homelab-infrastructure/network-wi-fi.json:panel-1]
- [x] [Review][Patch] Reconnects count reboots, driver reloads and returns to an earlier access point, and miss a drop still ongoing at the end of the range; panel and doc now say so [grafana-cloud/manifests/git-sync/homelab-infrastructure/network-wi-fi.json:panel-2]
- [x] [Review][Patch] The Connection table shows the state at the end of the time range, so a node disconnected then is not listed; panel and doc now say so [docs/grafana-cloud/wifi.md:23]
- [x] [Review][Patch] The node variable also offers a node with an unused `wl*` card, whose panels show "No data"; the doc now says so (filtering on `operstate="up"` would hide disconnected nodes again) [docs/grafana-cloud/wifi.md:17]
- [x] [Review][Patch] A deferred-work entry said "no Molecule scenario covers the Alloy role"; the cloud scenario does, with the cloud template [_bmad-output/implementation-artifacts/deferred-work.md:200]
- [x] [Review][Defer] The cloud `alloy` verify has no `'wifi' not in alloy_config` assert [configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml] — deferred: Epic 9 forbids changes under `configs-cloud/`; fits the Epic 6 guard
- [x] [Review][Defer] No standing check for the fleet collector line or the Git Sync manifests [configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2:58] — deferred: the gap predates this change and is already logged; Epic 6
- [x] [Review][Defer] Whether SSID, BSSID and `mac_address` should go to Grafana Cloud is undecided [configs-homelab/ansible/roles/grafana-cloud/alloy/README.md] — deferred: user decision

#### Rejected

- Spec status `done` while the live-data ACs are open (Acceptance Auditor, Blind Hunter, Edge Case Hunter): the fix edits the specs under review. Sprint status keeps both stories in `review`, as the AGENTS.md Git Sync pitfall requires.
- Stale notes on the `fritz-box-status.json` deletion, the empty Spec Change Log, and the Tasks line still naming `node_wifi_station_info` as the variable source (Acceptance Auditor, Blind Hunter, Edge Case Hunter): the fix edits the specs under review. The deletion is in `5694b1e` at the user's request.
- The deletion breaks the 9.2 rule "no change to existing dashboards" (Acceptance Auditor): false. The user asked for the deletion on 2026-10-23; it removes a duplicate of `000000013` and leaves the user's renamed dashboard unchanged.
- Story 9.1 AC 2 is not met and has no row for nodes without Wi-Fi (Acceptance Auditor, Blind Hunter): this is the open rollout gate, tracked in sprint status and the 9.1 Acceptance Check, not a code defect.
- The 9.1 spec contradicts itself on `success` 1 or 0 for nodes without Wi-Fi (Acceptance Auditor): the README gives the rule (1 means nl80211 was read, 0 with no error means no nl80211 or no permission). The container in the Investigation had the host's nl80211, so both are true. A fix would edit the spec.
- `max` on `connected_seconds_total` shows the old access point's value during a roam (Blind Hunter): false. With staleness markers the old series ends at the next scrape, so `max` picks the new one.
- A Wi-Fi interface not named `wl*` would be hidden (Edge Case Hunter): low. Every Wi-Fi interface in the fleet is `wl*`; a fallback adds a branch for a state not seen.
- The Connection table merge after a roam gives duplicate rows (Edge Case Hunter): low. With staleness markers both series overlap at most one scrape.
- The Git Sync reaction to the hand-made rename is unknown (Blind Hunter): low, maybe-false. The rename is the user's commit; the first sync after the merge shows it, and the dashboard name `000000013` is unchanged.
- The Alloy README has no link to the dashboard page, and there is no Wi-Fi runbook (Blind Hunter): low. Copied READMEs must not carry relative links (CLAUDE.md); a runbook is outside the ACs.
- `wifi.md` repeats the roaming text in two sections (Blind Hunter): low, cosmetic.
- The panels do not filter `device=~"wl.+"` like the variable does (Blind Hunter): low. Every `node_wifi_*` series comes from a Wi-Fi interface.
