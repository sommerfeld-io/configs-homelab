# Epic 5 Context: Grafana dashboard

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the DigitalOcean droplet running the fantasy hockey app observable in Grafana Cloud from the inside and the outside. The droplet runs unattended for months with a single operator, so the real long-term risk is neglect. One dashboard shows host, app, container and log data in one place. An external synthetic probe of the public URL catches outages on the path to the droplet that internal telemetry misses; the old Raspberry Pi setup had exactly that failure, where external requests timed out while internal monitoring showed no downtime. This epic completes the observability capability whose label groundwork was laid in Epic 3.

## Stories

- Story 5.1: Grafana dashboard for the droplet and the app
- Story 5.2: Synthetic monitoring check for the public URL
- Story 5.3: Caddy logs and certificate status on the droplet dashboard (added 2026-10-15, after Epic 7 brought Caddy)

## Requirements & Constraints

- The dashboard covers CPU, memory and other host metrics, the app itself (its `:8080/metrics`), container metrics, and logs of all containers on the droplet.
- The dashboard has no alert rules ("observe first"). The only alerts are the three built-in rules every Grafana Cloud Synthetic Monitoring check gets (`grafana_synthetic_monitoring_check_alerts` in `grafana-cloud/opentofu/checks.tf`), so Story 5.2's check brought them. Nothing in the repo routes them to a contact point yet; whether they should notify anyone is Epic 5 retro action item 32. Reconciled with the as-built on 2026-10-16 (retro action item 31).
- The synthetic check probes the public URL `https://fantasy-hockey.prod.do.sommerfeld.app` (Caddy in front of the app, Epic 7) from outside, in the same way as the existing Grafana Cloud synthetic checks that run from Frankfurt and Paris. The original plan was `http://<reserved-ip>` behind nginx; the 2026-10-15 sprint change moved Story 5.2 after Epic 7.
- Synthetic monitoring is a "Should" priority within an epic that is itself a "Should" (it comes after the Must epics for droplet, provisioning and deploy).
- Settled in Story 5.2: the existing checks moved into OpenTofu (`grafana-cloud/opentofu`), and the droplet check is one more entry in `local.checks` in `checks.tf`.
- Each story updates the docs under `docs/cloud/digital-ocean` in the same change.

## Technical Decisions

- Dashboard location: `grafana-cloud/manifests/git-sync/apps`. It reaches Grafana Cloud via git sync, not via manual UI edits.
- Label contract: every Alloy-shipped series carries `environment` (`homelab` or `digital-ocean`), and only droplet series also carry `stage` (currently `prod`). Filter droplet data with `environment="digital-ocean"`, optionally scoped by `stage`. The homelab has no `stage` label. `source` is an existing label with a different meaning, so do not repurpose it.
- `stage` is defined once in OpenTofu (droplet tag and name `prod-fantasy-hockey`) and reaches Ansible only through the tag. Allowing for further stages later (for example `test`) is a design goal, so a `stage` dashboard variable is a natural fit. Do not hardcode a single host.
- Alloy on the droplet is installed by the fleet Alloy role with the cloud config template under `configs-cloud/digital-ocean/ansible/templates/alloy/`. It ships OS metrics, container metrics, logs and the app scrape at `:8080/metrics`. If the dashboard needs a series that is not shipped yet, the change belongs in that cloud template, not in the fleet `config.alloy.j2`.
- The droplet is verified only by Alloy telemetry and the external synthetic check. The InSpec baseline does not cover it.
- Droplet facts relevant to panels: `s-1vcpu-1gb` in `fra1`, Ubuntu 26.04, a swap file, the app as docker compose (Caddy plus the app since Epic 7, nginx before) run by user `fantasy-hockey`, and data on a 2 GB volume at `/mnt/prod_fantasy_hockey_data`. Disk and memory headroom panels are useful because resizing changes CPU and RAM only, never disk.
- Grafana secrets stay in vault-encrypted `configs-homelab/ansible/vars/grafana-vault.yml`. Never commit credentials into manifests.

## Cross-Story Dependencies

- Both stories depend on Epic 3 (Alloy on the droplet with the `environment` and `stage` labels, and `environment=homelab` on the fleet) and Epic 4 (the app deployed on the droplet). Story 5.2 also depends on Epic 7 (the domain and HTTPS through Caddy).
- Stories 5.1 and 5.2 are independent of each other.
- Story 5.3 extends the 5.1 dashboard and depends on Epic 7 (Caddy). Its certificate-expiry panel reads Story 5.2's synthetic check, so 5.3 is built after 5.2. Caddy masks client IPs in its access log (IPv4 /24, IPv6 /48) before they reach Grafana Cloud. The app has no `/monitoring` endpoint; its `/metrics` is the monitoring endpoint and is already on the dashboard. Caddy's logs already reach Loki through the Docker log source, so 5.3 adds a `log_type` label in the cloud Alloy template, not a new collector.
- Epic 6 (GitHub Actions) does not depend on this epic. A later hardening epic adds a post-deploy smoke test of the public URL, which is separate from the synthetic check.
