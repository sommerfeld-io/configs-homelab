# Monitoring

The droplet and the fantasy hockey app have one Grafana Cloud dashboard: `Apps / Fantasy Hockey / Droplet` in the folder `apps`. It shows the host, the app, the containers and the logs of all containers on the droplet. It has no alert rules: for now the droplet is observed first, alerting comes later.

## Where the Dashboard Lives

The dashboard is a hand-written manifest in this repository:

| File                                                                | Content                                           |
|---------------------------------------------------------------------|---------------------------------------------------|
| `grafana-cloud/manifests/git-sync/apps/_folder.json`                | The Grafana folder `apps`                         |
| `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json` | The dashboard (schema `dashboard.grafana.app/v2`) |

It reaches Grafana Cloud through Git Sync once the commit lands on `main`, the branch Git Sync reads. A dashboard change on a feature branch shows up only after the merge. Edits made later in the Grafana Cloud UI are written back to this file by Git Sync (see `grafana-cloud/manifests/git-sync/README.md`). Git Sync may rewrite IDs or the formatting of the files on its first sync, which is expected.

## Label Filter

Every query filters on `environment="digital-ocean"` and on the dashboard variable `stage` (`stage=~"$stage"`), so homelab series never show up. These labels are the `external_labels` of the droplet's Alloy config, see [Alloy and Labels](provisioning.md#alloy-and-labels). No query names the droplet or its IP.

| Variable    | Source                                                                    | Default |
|-------------|---------------------------------------------------------------------------|---------|
| `stage`     | `label_values(up{environment="digital-ocean"}, stage)`                    | `prod`  |
| `container` | cAdvisor label `name` of `container_cpu_usage_seconds_total` (multi, All) | All     |

A second droplet with its own stage (for example `test`) appears in the `stage` list without a dashboard change.

## Rows

| Row        | Panels                                                                                                                                                                                            |
|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Overview   | App up and cAdvisor up (red when down), uptime, CPU %, memory %, swap used, used share of the root disk and of the data volume (`/mnt/<droplet_name>_data`, red `No data` when it is not mounted) |
| Host       | CPU by mode, memory and swap, disk usage per mount point, disk I/O, network rx/tx per interface, load average                                                                                     |
| App        | Request rate by route and by status, 5xx rate, p50/p95 latency, login events, prediction saves, process memory, goroutines                                                                        |
| Containers | CPU, working set memory and network rx/tx per container (cAdvisor), filtered by `$container`                                                                                                      |
| Logs       | Docker logs of the containers in `$container` (job `integrations/docker`), journal logs of the droplet (job `integrations/node_exporter`)                                                         |

The app panels leave out `route="GET /metrics"`: Alloy scrapes that route every 30 seconds, which would otherwise dominate the request rate. They come from the app's own metrics, so responses Caddy answers itself (502 while the app is down or unreachable) are not counted; the App stat and the container logs show that case. The Overview stats are instant queries: when Alloy stops sending, they show `No data` instead of the last value of the time range. Disk and memory headroom matter on this droplet because resizing it changes CPU and RAM only, never the disk.

All panels use series the cloud Alloy config (`configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`) ships today: node exporter, journal logs, Docker logs, cAdvisor and the app scrape at `localhost:8080/metrics` (job `fantasy-hockey`). A panel that needs a new series needs a change to that template first.

## Checks

After the commit is on `main` and Git Sync picked it up, open `Apps / Fantasy Hockey / Droplet` with `stage=prod`:

- The App and cAdvisor stats show `Up`, and Volume Disk shows a percentage, not `No data`.
- CPU, memory, disks, the app panels, the container panels and the container logs show data.
- The dashboard has no alert rules.
