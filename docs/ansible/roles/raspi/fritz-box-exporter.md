# Role: RasPi / Fritz Box Exporter

This role deploys [`sberk42/fritzbox_exporter`](https://github.com/sberk42/fritzbox_exporter) as a Docker Compose service on `pi4-dradis`, exposing Prometheus metrics for an AVM FRITZ!Box 6591 Cable modem — WAN throughput/uptime/connected-host counts (via UPnP/TR-064) and DOCSIS cable metrics (downstream/upstream power, MSE, correctable/uncorrectable codeword errors, via the box's `data.lua` API).

`files/docker-compose.yml` and `files/metrics-lua-cable.json` are plain, static files (no Ansible templating) copied to `{{ raspi_fritz_box_exporter_path }}`, and the container is brought up with `pull: always` so the pinned digest is always re-verified. FRITZ!Box credentials are never written to disk on the target: `FRITZBOX_USERNAME`/`FRITZBOX_PASSWORD` are set as task-level environment variables on the `docker_compose_v2` calls, and the plain compose file references them via Docker Compose's own `${VAR}` interpolation, which reads from that process environment.

Metrics themselves are **not** shipped by a dedicated Alloy instance in this stack — this exporter is scraped by the homelab's existing, single, fleet-wide Alloy agent (`ansible/roles/grafana-cloud/alloy`), which already runs on every host including `pi4-dradis`. A static `localhost:9042` scrape target was added to that shared `config.alloy.j2` template, following the exact same convention already used for the Ollama integration: the same rendered config goes to every host, and on hosts other than `pi4-dradis` the target simply reports `up=0` — no errors. See that role's template for details.

## Manual prerequisites

### 1. FRITZ!Box

1. Create a dedicated, restricted user: **System → FRITZ!Box-Benutzer**. Grant only the minimum rights needed to read status information — do **not** grant NAS, telephony, or Smart Home access.
2. Enable TR-064 access: **Heimnetz → Netzwerk → Netzwerkeinstellungen → "Zugriff für Anwendungen zulassen"** (also labelled "Statusinformationen über UPnP übertragen").
3. Note the ports used: `49000` (TR-064 HTTP, UPnP/WAN metrics) and `49443` (TR-064 HTTPS, not used by this role).

### 2. Grafana Cloud

No new Grafana Cloud credentials are needed for this role. Metrics ride the homelab's existing shared Alloy pipeline and its existing `ansible/vars/grafana-vault.yml` credentials, which are already applied to `pi4-dradis` via `ansible/playbooks/grafana-agents.yml`.

### 3. Git Sync caveat

`grafana-cloud/manifests/git-sync/README.md` states that directory is Grafana-owned and should be treated as read-only — normally, all dashboard/folder changes are made through the Grafana Cloud UI and synced down automatically. For this role, `grafana-cloud/manifests/git-sync/network/_folder.json` and `fritz-box-cable-modem.json` were **hand-written directly into the repo**, ahead of the `network` folder actually existing in Grafana Cloud, by explicit choice. The folder's `metadata.name` is a fabricated placeholder UID — expect Grafana Cloud's Git Sync to reconcile (and likely overwrite) it once it processes this folder for the first time. All dashboard panel expressions were built from the exporter's static metric-definition files on GitHub, not from a live `/metrics` scrape — verify and correct them against the real output before relying on the dashboard.

### 4. Secrets

`ansible/host_vars/pi4-dradis/fritz-box-vault.yml` currently holds empty placeholder values for `fritzbox_username` / `fritzbox_password` (the FRITZ!Box user created above) and is **not yet Ansible Vault-encrypted** — fill in the real values and vault-encrypt it yourself when ready:

```bash
ansible-vault encrypt ansible/host_vars/pi4-dradis/fritz-box-vault.yml
```

No other change is needed afterwards — this file is loaded via `vars_files` in `ansible/playbooks/raspi.yml`, which transparently decrypts vault-encrypted files.

## Running the role

```bash
ansible-playbook ansible/playbooks/raspi.yml --limit pi4-dradis.fritz.box --tags fritz-box-exporter --ask-become-pass --ask-vault-pass
```

## Verifying

1. `curl http://pi4-dradis.fritz.box:9042/metrics | grep gateway_` — confirm real metric names, and correct the role's post-deploy assertion / the dashboard's panel expressions if they differ from what was assumed.
2. Confirm the target is being scraped: check the Alloy UI or Grafana Cloud Explore for `job="integrations/fritz-box-exporter"`. This requires `ansible/playbooks/grafana-agents.yml` to have been (re-)run after the shared Alloy config was updated.
3. Confirm the dashboard renders under the `network` folder in Grafana Cloud once Git Sync reconciles.

## Default Variables

| Variable                        | Default                   | Description                             |
|---------------------------------|---------------------------|-----------------------------------------|
| `raspi_fritz_box_exporter_path` | `/opt/fritz-box-exporter` | Path where the compose file is deployed |

## Required Variables

| Variable            | Description                                                                                      |
|---------------------|--------------------------------------------------------------------------------------------------|
| `default_user`      | The user that owns the deploy directory and compose file on the node                             |
| `fritzbox_username` | FRITZ!Box user created above; loaded from `ansible/host_vars/pi4-dradis/fritz-box-vault.yml`     |
| `fritzbox_password` | Password for `fritzbox_username`; loaded from `ansible/host_vars/pi4-dradis/fritz-box-vault.yml` |
