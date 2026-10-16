# Synthetic Monitoring

The Grafana Cloud Synthetic Monitoring checks for the public websites are declared with OpenTofu in `grafana-cloud/opentofu`. The layout follows the DigitalOcean root in `configs-cloud/digital-ocean/opentofu`: one root module, local state in `terraform.tfstate` (gitignored), exact version pins and a taskfile.

## What Is Managed

| Check                                   | Job                              | Target                                          | Probes           | Frequency | `HTTPRequestDurationTooHighAvg` |
|-----------------------------------------|----------------------------------|-------------------------------------------------|------------------|-----------|---------------------------------|
| `www.fb-brunnenbau.de`                  | `up-and-running___websites`      | `https://www.fb-brunnenbau.de`                  | Frankfurt, Paris | 10 min    | 1200 ms                         |
| `www.minifigs.de`                       | `up-and-running___websites`      | `https://www.minifigs.de`                       | Frankfurt, Paris | 10 min    | 2000 ms                         |
| `fantasy-hockey.prod.do.sommerfeld.app` | `up-and-running___digital-ocean` | `https://fantasy-hockey.prod.do.sommerfeld.app` | Frankfurt, Paris | 10 min    | 300 ms                          |

Every check is an HTTP `GET` over IPv4. The job label and the probe locations are set per check. It fails without TLS, follows redirects, has a 10 s timeout and carries the label `site=<key>`. Every check has the same three alert rules (`grafana_synthetic_monitoring_check_alerts`):

| Alert                                 | Threshold           | Period |
|---------------------------------------|---------------------|--------|
| `ProbeFailedExecutionsTooHigh`        | 2                   | 30m    |
| `TLSTargetCertificateCloseToExpiring` | 5 (days), per check | none   |
| `HTTPRequestDurationTooHighAvg`       | per check           | 1h     |

The certificate expiry threshold defaults to 5 days and can be set per check with `tls_expiry_threshold_days`. The fantasy hockey app on the DigitalOcean droplet uses 14 days: Caddy renews its certificate when about 30 days are left, so an alert at 14 days means renewal has been failing for two weeks (see [Monitoring](../cloud/digital-ocean/monitoring.md)). A certificate that is invalid fails the check on every run, because the probes verify it and the check requires TLS.

## Probe Locations

Probe locations are referenced by name, never by ID. `probes.tf` looks up the IDs of the public probes with the data source `grafana_synthetic_monitoring_probes` and exposes them as `local.probe_location_frankfurt` and `local.probe_location_paris`. A check lists the locations it runs from in its `probes` option. For a new location, add a local with the probe's name as shown in Synthetics > Probes. A name that does not exist fails the plan.

## Files

- `versions.tf`: OpenTofu and `grafana/grafana` provider pins, and the provider with the Synthetic Monitoring API URL (`eu-west-2`).
- `probes.tf`: the probe locations, looked up by name.
- `checks.tf`: the `checks` map (one entry per website, options documented in its header comment), the shared settings, the checks and their alerts.
- `outputs.tf`: the check ID of each site.
- `taskfile.yml`: the tasks below.

## Add a Check

Add an entry with `job`, `probes`, `target` and `http_duration_threshold_ms` to `local.checks` in `checks.tf` and run `task grafana-cloud:plan`, then `task grafana-cloud:apply`. The new check gets the shared settings and the three alerts. Never create or edit a check in the Grafana Cloud UI: OpenTofu owns every check, and a UI change is reverted by the next apply.

## Access Token

The provider only talks to the Synthetic Monitoring API, so it needs no Grafana instance URL and no service account token. It reads a Synthetic Monitoring access token from the environment variable `GRAFANA_SM_ACCESS_TOKEN`. The Alloy key (`grafana_cloud_api_key`) does not work here: it is an access policy token for writing metrics, logs and traces, and the Synthetic Monitoring API rejects it.

Because no Grafana instance API token is used, OpenTofu does not manage Grafana folders: sorting checks into folders (`folder_uid`) would need a folder created through the Grafana instance API.

1. In Grafana Cloud, create the token under Testing & synthetics > Synthetics > Config > Access tokens.
2. Add it as `GRAFANA_SM_ACCESS_TOKEN` to `configs-homelab/ansible/vars/grafana-vault.yml` (`task homelab:ansible:vault:grafana`). The `desktop` playbook loads this vault file, so the entry must exist before the playbook runs.
3. Provision the workstation with the `desktop` playbook. It writes `export GRAFANA_SM_ACCESS_TOKEN=...` to the default user's `.bashrc` through `configs-homelab/ansible/tasks/bash-secrets.yml`.
4. The devcontainer sets `GRAFANA_SM_ACCESS_TOKEN` from the host environment through `containerEnv`. Start VS Code from a shell where the variable is set, then rebuild the devcontainer.

Check it with `echo "${GRAFANA_SM_ACCESS_TOKEN:+set}"`. `plan`, `apply` and `apply:yes` stop with a hint to this page when the variable is empty.

## Tasks

| Task                           | What it does                                     |
|--------------------------------|--------------------------------------------------|
| `task grafana-cloud:init`      | `tofu init`                                      |
| `task grafana-cloud:fmt`       | `tofu fmt -recursive` (also part of `task lint`) |
| `task grafana-cloud:validate`  | `tofu validate`                                  |
| `task grafana-cloud:plan`      | `tofu plan`                                      |
| `task grafana-cloud:apply`     | `tofu apply`                                     |
| `task grafana-cloud:apply:yes` | `tofu apply -auto-approve`, read `plan` first    |

`lint-opentofu` (`docker-compose.yml`) checks the formatting of `grafana-cloud` together with `configs-cloud`. No GitHub Actions workflow applies this configuration yet.

## Fully Managed by OpenTofu

OpenTofu creates every check from `checks.tf`, and nothing is imported. The two checks first created in the Grafana Cloud UI were deleted there and created again by OpenTofu. They got new check IDs, and their earlier results stay in Grafana Cloud's metrics.

The API refuses a second check with the same target and job (`409 Conflict: target/job combination already exists`). So if an apply fails with this error, a check for that site still exists outside OpenTofu: delete it in the UI and apply again.

A second plan after an apply must show no changes:

```bash
cd grafana-cloud/opentofu
tofu plan -detailed-exitcode   # exit code 0 = no changes, 2 = changes
```

## State

The state is local (`terraform.tfstate`, gitignored) and is the only link between `checks.tf` and the checks in Grafana Cloud. If it is lost, the next apply tries to create every check again and fails with `409 Conflict`. Then either delete the checks in the UI and apply, or import them with `tofu import 'grafana_synthetic_monitoring_check.this["<site>"]' <check-id>` and `tofu import 'grafana_synthetic_monitoring_check_alerts.this["<site>"]' <check-id>`. `tofu output check_ids` lists the IDs while the state still exists.
