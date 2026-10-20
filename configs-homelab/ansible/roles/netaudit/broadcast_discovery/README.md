# Role: Netaudit Broadcast Discovery

Finds devices and services that announce themselves via broadcasts and never show much in a port scan, and detects rogue DHCP servers.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Netaudit playbook (`configs-homelab/ansible/playbooks/netaudit.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap --script broadcast-dhcp-discover,broadcast-dns-service-discovery,broadcast-upnp-info` on the interface of the default route and prints two tables:

- **DHCP servers:** `SERVER`, `OFFERED IP`, `ROUTER`, `DNS`, `DOMAIN`. Warns if more than one DHCP server answers
- **mDNS services and UPnP devices:** `IP`, `HOSTNAME`, `PROTOCOL`, `SERVICE / DEVICE`, `DETAILS` (model for mDNS, manufacturer and model for UPnP). Hostnames come from the `device_discovery` scan
- Tagged `lan-scan-broadcast`

The role uses no subnet, broadcasts reach the local network of the default interface only.

## Markdown Reports

When the play sets `netaudit_reports: true` (the Netaudit playbook does), the role also writes its findings as markdown reports to `{{ broadcast_discovery_report_dir }}` (default: `{{ netaudit_reports_dir }}/broadcast_discovery`, i.e. `target/netaudit/broadcast_discovery/` in the repository root). The console output stays the same.

- `dhcp-servers.md`: DHCP servers, the warning about several DHCP servers as a note
- `mdns-upnp-devices.md`: mDNS services and UPnP devices

The reports are written on the Ansible controller by the shared `netaudit/report` helper (`delegate_to: localhost`, without `become`, so the files belong to the user running the playbook). Each report states its status: `completed` (with the number of findings, or "No findings" for an empty result), `failed: <error>` when the scan failed (the role then fails as well) or `skipped: <reason>`. Reports of scans that did not run in this playbook run are not written.

## Optional Variables

The following variables are optional and have default values:

| Variable                               | Description                       | Default                                                                                                                  |
|----------------------------------------|-----------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `{{ broadcast_discovery_report }}`     | Write markdown reports            | `{{ netaudit_reports }}` if set, otherwise `false`                                                                       |
| `{{ broadcast_discovery_report_dir }}` | Directory of the markdown reports | `{{ netaudit_reports_dir }}/broadcast_discovery`, otherwise `target/netaudit/broadcast_discovery` in the repository root |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
