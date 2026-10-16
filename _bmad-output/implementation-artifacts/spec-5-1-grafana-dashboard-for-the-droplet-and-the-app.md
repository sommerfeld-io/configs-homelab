---
title: 'Story 5.1: Grafana dashboard for the droplet and the app'
type: 'feature'
created: '2026-10-15'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '4268e202fbad3398f89a98a92a748ffe9785e66c'
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The droplet and the fantasy hockey app ship metrics and logs to Grafana Cloud (labels `environment="digital-ocean"`, `stage`), but there is no dashboard for them; the homelab dashboards are keyed per homelab node and do not show the app.

**Approach:** One hand-written Grafana dashboard (schema `dashboard.grafana.app/v2`, like `summary/summary-nodes-up.json`) in a new folder `grafana-cloud/manifests/git-sync/apps`, reaching Grafana Cloud through Git Sync. It shows the host (CPU, memory, swap, disks, network), the app, the containers and the logs of all containers, filtered by a `stage` variable, with no alert rules. Docs under `docs/cloud/digital-ocean` describe it.

## Boundaries & Constraints

**Always:** Filter every query by `environment="digital-ocean"` and `stage=~"$stage"`; never hardcode the droplet name or IP. Use only series the cloud Alloy config ships today (`configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`). Datasources by name: `grafanacloud-prom`, `grafanacloud-logs`. JSON must parse; filenames kebab-case.

**Never:** No alert rules, no alert-backed panels, no Alloy or app changes. Do not touch existing dashboards. No credentials or tokens in the manifests. Agent never edits Grafana Cloud through its API or UI.

## I/O & Edge-Case Matrix

| Scenario               | Input / State                                     | Expected Output / Behavior                                      | Error Handling                  |
|------------------------|---------------------------------------------------|-----------------------------------------------------------------|---------------------------------|
| Normal                 | droplet `prod` up, app and cAdvisor scraped       | all panels show data for `stage=prod`                           | N/A                             |
| App down               | `up{job="fantasy-hockey"}` = 0                    | app status stat shows down (red), other host panels keep data   | N/A                             |
| Scrape noise           | Alloy scrapes `GET /metrics` every 30 s           | request-rate and error panels exclude `route="GET /metrics"`    | N/A                             |
| Second stage later     | a `test` droplet with `stage="test"`              | `stage` variable lists both; panels follow the selection        | N/A                             |
| Homelab data           | homelab series without `environment=digital-ocean`| never shown                                                     | N/A                             |

</frozen-after-approval>

## Code Map

- `grafana-cloud/manifests/git-sync/summary/summary-nodes-up.json` -- hand-written v2 dashboard (commit `c7aca03`): copy its top-level shape (`apiVersion`, `kind`, `metadata.name`, `spec` keys `annotations`, `elements`, `layout` `GridLayout`, `variables`, `timeSettings`).
- `grafana-cloud/manifests/git-sync/linux-node/docker-containers-by-node.json` -- v2 panels to reuse for container CPU/memory/network (cAdvisor label `name`) and Loki log panels; its query/datasource JSON shape is the template.
- `grafana-cloud/manifests/git-sync/network/_folder.json` -- folder manifest shape (`folder.grafana.app/v1beta1`); `metadata.name` is a placeholder UID Git Sync reconciles.
- `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2` -- shipped series: node exporter (`job="integrations/node_exporter"`), journal logs (`job="integrations/node_exporter"`, label `unit`), Docker logs (`job="integrations/docker"`, label `container`), cAdvisor (`job="integrations/cadvisor"`, allow-list at line 229), app (`job="fantasy-hockey"`); `instance` = droplet hostname everywhere.
- App metrics (read from the droplet's `/metrics`): `fantasy_hockey_http_requests_total{route,status}`, `fantasy_hockey_http_request_duration_seconds_bucket{route,status,le}`, `fantasy_hockey_login_events_total{event}`, `fantasy_hockey_prediction_saves_total{kind}`, plus Go `go_*` and `process_*`.
- Volume mount point: `/mnt/<droplet_name>_data` (e.g. `/mnt/prod_fantasy_hockey_data`); match it with `mountpoint=~"/mnt/.+_data"`.
- `docs/cloud/digital-ocean/` and `mkdocs.yml` nav `Cloud > Digital Ocean` -- add a page.

## Tasks & Acceptance

**Execution:**
- [x] `grafana-cloud/manifests/git-sync/apps/_folder.json` -- folder `apps`, placeholder UID like `network/_folder.json`.
- [x] `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json` -- dashboard titled `Apps / Fantasy Hockey / Droplet`, tags `digital-ocean`, `fantasy-hockey`; variables `stage` (`label_values(up{environment="digital-ocean"}, stage)`, default `prod`) and `container` (multi, include All, from `container_cpu_usage_seconds_total` `name`); rows: Overview (app up, cAdvisor up, uptime, CPU %, memory %, swap used, root and volume disk used %), Host (CPU by mode, memory and swap, disk usage per mount point, disk I/O, network rx/tx, load), App (request rate by route and by status, 5xx rate, p50/p95 latency, login events, prediction saves, process memory and goroutines), Containers (CPU, memory working set, network per container), Logs (container logs filtered by `$container`, journal logs) -- the dashboard the story asks for.
- [x] `docs/cloud/digital-ocean/monitoring.md` + `mkdocs.yml` -- page "Monitoring": where the dashboard lives, what each row shows, the label filter, that it reaches Grafana Cloud through Git Sync after the commit lands on the synced branch, and that there are no alerts; link from `index.md` where Grafana Cloud is mentioned if it fits.

**Acceptance Criteria:**
- Given the commit, when `python3 -m json.tool` runs on both new files, then both parse, and every query references `environment="digital-ocean"`.
- Given `task lint`, when it runs, then it passes.
- Given Git Sync has picked up the commit, when the user opens the dashboard with `stage=prod`, then CPU, memory, disks, app, containers and container logs show data and the dashboard has no alert rules.

### Review Findings

Code review of `e8a61ec` (2026-10-15), layers: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor.

- [x] [Review][Patch] Name `main` as the branch Git Sync reads [docs/cloud/digital-ocean/monitoring.md:15] — decision (user, 2026-10-15): Git Sync reads `main`, so the dashboard and AC 3 appear only after the merge of PR #366.
- [x] [Review][Patch] Overview stats CPU, Memory, Swap Used, Root Disk and Volume Disk show stale values as current [grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json:panel-4..panel-8] — range queries reduced with `lastNotNull` keep the last sample of the 6 h window green after Alloy or node exporter stops, so the null mapping on Volume Disk never fires; make them instant queries like panel-1 to panel-3.
- [x] [Review][Patch] Volume Disk null text "Not mounted" claims a cause the panel cannot know [grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json:panel-8] — null also means Alloy down or no matching mount; use "No data" in red and name the causes in the description.
- [x] [Review][Patch] Swap Used description says steady swap use means memory shortage [grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json:panel-6] — Linux keeps pages in swap after pressure ends; reword to a rising value.
- [x] [Review][Patch] 5xx panel and docs do not say nginx's own 502/504 are not counted [grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json:panel-17] — app metrics never see responses nginx answers itself when the app is down; say so in the description and in `monitoring.md`.
- [x] [Review][Patch] "this stage is about observing first" clashes with the `stage` label [docs/cloud/digital-ocean/monitoring.md:3] — reword.
- [x] [Review][Patch] Docs omit the Volume Disk red state and its check [docs/cloud/digital-ocean/monitoring.md:31] — the Overview row and Checks name only App and cAdvisor.
- [x] [Review][Patch] Deferred entry points at `config.alloy.j2:229` by line number [_bmad-output/implementation-artifacts/deferred-work.md] — refer to the `prometheus.relabel "integrations_cadvisor"` keep rule instead.
- [x] [Review][Defer] No lint or CI check reads the git-sync manifests [grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json] — deferred: carried from triage row 1, already in `deferred-work.md`.
- [x] [Review][Defer] Alloy Molecule verify does not pin job names and the cAdvisor keep-list [configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml] — deferred: carried from triage row 2, already in `deferred-work.md`.
- [x] [Review][Defer] Epic 5 context says "not via manual UI edits" while `monitoring.md` and Git Sync write UI edits back [_bmad-output/implementation-artifacts/epic-5-context.md] — deferred: same root as the README item in `deferred-work.md`; the fix edits a planning doc.

Rejected:

- false — Disk I/O lacks a device filter: Alloy's unix exporter excludes partitions, loop and ram devices by default in `diskstats`.
- false — Container CPU above 100 % after a resize: the description says "share of one core", so 150 % is 1.5 cores, as stated.
- false — Login and prediction panels show no data before the first event: the counters exist from start with value 0 (read from the droplet's `/metrics`).
- false — `stage=~"$stage"` regex metacharacters: DigitalOcean tags allow only letters, digits, `_`, `-`, `:`.
- false — built-in annotation query lacks the label filter: it is Grafana's default `-- Grafana --` annotation, not a data query or alert rule.
- false — spec `done` vs sprint `review`: `bmad-build` marks the spec done and the story `review` by design; this review sets the final status.
- false — container log filter depends on cAdvisor: All resolves to `.+` even with an empty variable.
- spec edit — triage row 7 rationale is wrong (covered by the stale-stats patch above), Code Map says `GridLayout`, Verification omits `_folder.json` and the audit script.
- low — no OOM-kill panel, no log error-count panel, no 5xx ratio: new panels beyond the story, more than a direct correction.

## Implementation Notes

- Dashboard generated by a script (27 panels in 5 `RowsLayout` rows, variables `stage` single-select default `prod`, `container` multi with All = `.+`); both JSON files parse; `task lint` passed.
- Verification pass: `monitoring.md` said nobody edits the dashboard in the Grafana UI; Git Sync writes UI edits back (FRITZ!Box `update dashboard` commits), so the line now says that.
- Matrix audit (no test framework applies to dashboard JSON; checked by script over the manifest): Homelab data -- all 39 queries carry `environment="digital-ocean"`; Scrape noise -- request rate, status, 5xx and latency queries carry `route!="GET /metrics"`; App down -- App stat maps `0` and null to red `Down`/`No data`; Second stage -- `stage` comes from `label_values(up{environment="digital-ocean"}, stage)` and every query uses `stage=~"$stage"`; Normal -- needs live data, left to the user's check after Git Sync (AC 3).
- App metric names `process_resident_memory_bytes`, `go_memstats_heap_inuse_bytes`, `go_goroutines` confirmed in the droplet's `/metrics` output during planning.

## Spec Change Log

## Review Triage Log

| #  | Layer  | Finding                                                                 | Verdict     | Route  | Evidence                                                                                                                                                                 |
|----|--------|-------------------------------------------------------------------------|-------------|--------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | VG     | No check in `task lint` or CI reads the manifest (parse, label filter)  | medium      | defer  | Pre-verified gap: only ls-lint and folderslint touch `git-sync/`; a Git Sync write-back or edit dropping `environment="digital-ocean"` would pass.                        |
| 2  | VG     | Alloy Molecule verify does not pin the job names and cAdvisor keep-list | medium      | defer  | Pre-verified gap: `alloy/verify.yml` asserts only the external labels; the dashboard is a new consumer of `job` values and `config.alloy.j2:229`.                        |
| 3  | EC, BH | Volume Disk stat has no null mapping                                    | low         | patch  | `panel-8` has no `mappings`; an unmounted volume shows grey `No data` while App and cAdvisor stats map null to red. Direct addition of the same mapping.                 |
| 4  | BH     | Load panel description hard-codes one vCPU                              | low         | patch  | `panel-14` description "The droplet has one vCPU." goes stale on a CPU resize, which the docs name as the expected scaling path. Direct deletion.                        |
| 5  | BH     | Login/prediction `increase(...[$__interval])` gets too few samples      | false       | reject | `panel-19`/`panel-20` set `queryOptions.interval: 5m`, so each window spans ten 30 s app scrapes.                                                                         |
| 6  | BH     | Node exporter 60 s default scrape may leave `$__rate_interval` too short | maybe-false | reject | Would be low (gaps only). Settled by checking the `grafanacloud-prom` scrape-interval setting; the homelab dashboards use the same 60 s scrape with `$__rate_interval`. |
| 7  | EC, BH | Host stats (uptime, CPU, memory, swap, root disk) and no host liveness stat go grey when Alloy stops | low | reject | A dead Alloy also turns the App and cAdvisor stats red `No data` (their `up` comes from Alloy); a new stat adds panels for an already visible state.            |
| 8  | EC, BH | 5xx panel "No data" cannot be told from a broken query                  | low         | reject | `noValue` reads "No 5xx responses" and the description says it is empty without errors; a broken query is unlikely in everyday use and the fix adds query branches.     |
| 9  | EC     | Latency quantiles are NaN on an idle app                                | low         | reject | Grafana draws NaN as gaps; cosmetic, and a guard adds query complexity.                                                                                                  |
| 10 | BH     | No container restart panel                                              | low         | reject | Restarts show as gaps in the container panels and in the container logs; a new panel is more than a direct correction.                                                    |
| 11 | BH     | Log panels lack text search and `unit` filter                           | low         | reject | Feature request beyond the story; Explore offers both.                                                                                                                    |
| 12 | BH     | `git-sync/README.md` still says "do not manually edit"                  | medium      | defer  | The contradiction predates this story (`c7aca03`, FRITZ!Box dashboards); the README rule is the user's, so changing it is their decision.                               |
| 13 | BH     | Spec `in-review` vs sprint status `in-progress`                         | low         | reject | Step 5 moves the story to `review`; the fix would only edit tracking files.                                                                                              |
| 14 | BH     | `monitoring.md` has no direct dashboard link                            | low         | reject | The stack URL is not in the repo; the title and folder name the dashboard.                                                                                               |
| 15 | BH     | `monitoring.md` Checks has no troubleshooting                           | low         | reject | `deployment.md` and `provisioning.md` hold the checks for the app and cAdvisor; not a defect of this page.                                                              |
| 16 | BH     | `docs/cloud/index.md` does not link the Monitoring page                 | low         | reject | The page is in the nav and linked from the Digital Ocean overview.                                                                                                       |
| 17 | BH     | Memory, Load legends have no `instance`                                 | false       | reject | One droplet per stage by design; a replacement keeps the same hostname, so `instance` would not separate the series either.                                              |

## Design Notes

`grafana-cloud/manifests/git-sync/README.md` says the folder is Grafana-owned and not edited by hand, but the repo already hand-writes dashboards there (`c7aca03`, the FRITZ!Box dashboards) and Git Sync reconciles them. This story follows that practice; Git Sync may rewrite IDs or formatting on its first sync, which is expected.

Layout: `RowsLayout` with one `RowsLayoutRow` (each holding a `GridLayout`) per row, exactly as `docker-containers-by-node.json` does (its rows: untitled overview, "CPU + Memory", "Network", "Filesystem I/O", "Logs - Container", "Logs - journald"). Element names `panel-1` … in layout order.

## Verification

**Commands:**
- `python3 -m json.tool grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json >/dev/null` -- expected: exit 0.
- `task lint` -- expected: all linters pass.

**Manual checks (if no CLI):**
- After Git Sync picked up the commit, the user opens `Apps / Fantasy Hockey / Droplet` in Grafana Cloud and confirms every row shows data for `stage=prod`; the agent can spot-check queries against Grafana Cloud only if the user provides read access.
