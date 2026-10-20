# Role: Netaudit Nmap

Installs nmap, the scanner of the nmap-based netaudit roles (`device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`). Each of them declares this role as a dependency in its `meta/main.yml`, so it runs once per play before the first of them.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Netaudit playbook (`configs-homelab/ansible/playbooks/netaudit.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

- Installs the `nmap` package with the distribution's package manager (Ubuntu and Arch Linux)
- The task is tagged `always`, so nmap is also installed when only single scans are selected with `--tags`

## Markdown Reports

This role has no findings and writes no report. All other netaudit roles write their findings as markdown reports when the play sets `netaudit_reports: true`. The reports go to `{{ netaudit_reports_dir }}/<role>/` (default: `target/netaudit/<role>/` in the repository root, which is gitignored). The shared `netaudit/report` role renders the console tables and the reports. The Netaudit playbook enables the reports.

The role has no variables.
