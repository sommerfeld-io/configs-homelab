# Role: Netaudit Service Detection

Detects open ports, service versions and operating systems of all devices on the network. Takes a few minutes.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Netaudit playbook (`configs-homelab/ansible/playbooks/netaudit.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -sV -O --osscan-guess --top-ports {{ service_detection_top_ports }} --open -T4` against `{{ subnet }}` and prints two tables:

- **Open ports and services:** `IP`, `HOSTNAME`, `PORT`, `SERVICE`, `VERSION`
- **Operating systems:** `IP`, `HOSTNAME`, `DISTRO (ANSIBLE FACTS)`, `OS (NMAP)`. nmap fingerprints the kernel but cannot tell Linux distributions apart, so the distribution and version come from the Ansible facts of the inventory hosts gathered earlier in the same run. Hosts outside the inventory or without facts show `-`

The scan result is registered as `service_detection_scan`. The `web_services` and `tls_certificates` roles take their ports from it, so the tasks are tagged `lan-scan-services`, `lan-scan-web` and `lan-scan-tls`.

## Markdown Reports

When the play sets `netaudit_reports: true` (the Netaudit playbook does), the role also writes its findings as markdown reports to `{{ service_detection_report_dir }}` (default: `{{ netaudit_reports_dir }}/service_detection`, i.e. `target/netaudit/service_detection/` in the repository root). The console output stays the same.

- `open-ports.md`: open ports and services
- `operating-systems.md`: operating systems

The reports are written on the Ansible controller by the shared `netaudit/report` helper (`delegate_to: localhost`, without `become`, so the files belong to the user running the playbook). Each report states its status: `completed` (with the number of findings, or "No findings" for an empty result), `failed: <error>` when the scan failed (the role then fails as well) or `skipped: <reason>`. Reports of scans that did not run in this playbook run are not written.

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                             | Description                                                                               | Default                                                                                                              |
|--------------------------------------|-------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `{{ service_detection_top_ports }}`  | Number of most common ports to scan per device                                            | `100`                                                                                                                |
| `{{ service_detection_distros }}`    | `host=distribution version\|...` list built from the Ansible facts of all inventory hosts | built from `hostvars`                                                                                                |
| `{{ service_detection_report }}`     | Write markdown reports                                                                    | `{{ netaudit_reports }}` if set, otherwise `false`                                                                   |
| `{{ service_detection_report_dir }}` | Directory of the markdown reports                                                         | `{{ netaudit_reports_dir }}/service_detection`, otherwise `target/netaudit/service_detection` in the repository root |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
