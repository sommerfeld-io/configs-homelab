# Role: Netaudit Web Services

Lists the web services on the network with their HTTP title and server header, and flags exposed APIs.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Netaudit playbook (`configs-homelab/ansible/playbooks/netaudit.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -sV --script http-title,http-server-header --open -T4` against `{{ subnet }}` on all HTTP(S) ports found by the `service_detection` role plus `{{ web_services_extra_ports }}`, and prints `IP`, `HOSTNAME`, `PORT`, `SERVER`, `TITLE` and `WARNING`.

- `WARNING` is set for an open Docker API without TLS (`2375`) and an open Ollama API without authentication (`11434`)
- Without the `service_detection` scan (e.g. skipped with `--skip-tags lan-scan-services`), only the extra ports are scanned
- Tagged `lan-scan-web`

## Markdown Reports

When the play sets `netaudit_reports: true` (the Netaudit playbook does), the role also writes its findings as markdown reports to `{{ web_services_report_dir }}` (default: `{{ netaudit_reports_dir }}/web_services`, i.e. `target/netaudit/web_services/` in the repository root). The console output stays the same.

- `web-services.md`: web services and API warnings

The reports are written on the Ansible controller by the shared `netaudit/report` helper (`delegate_to: localhost`, without `become`, so the files belong to the user running the playbook). Each report states its status: `completed` (with the number of findings, or "No findings" for an empty result), `failed: <error>` when the scan failed (the role then fails as well) or `skipped: <reason>`. Reports of scans that did not run in this playbook run are not written.

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                         | Description                                                             | Default                                                                                                    |
|----------------------------------|-------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| `{{ web_services_extra_ports }}` | Ports probed in addition to the HTTP(S) ports found by the service scan | `11434` (Ollama), `2375`, `2376` (Docker API)                                                              |
| `{{ web_services_ports }}`       | Comma-separated ports to scan                                           | HTTP(S) ports from `service_detection_scan` plus the extra ports                                           |
| `{{ web_services_report }}`      | Write markdown reports                                                  | `{{ netaudit_reports }}` if set, otherwise `false`                                                         |
| `{{ web_services_report_dir }}`  | Directory of the markdown reports                                       | `{{ netaudit_reports_dir }}/web_services`, otherwise `target/netaudit/web_services` in the repository root |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
