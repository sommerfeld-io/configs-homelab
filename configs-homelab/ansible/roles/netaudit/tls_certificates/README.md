# Role: Netaudit TLS Certificates

Lists the TLS certificates on the network with issuer, expiry and cipher grade.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Netaudit playbook (`configs-homelab/ansible/playbooks/netaudit.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -sV --script ssl-cert,ssl-enum-ciphers --open -T4` against `{{ subnet }}` on all TLS ports found by the `service_detection` role, and prints `IP`, `HOSTNAME`, `PORT`, `SUBJECT`, `ISSUER`, `SELF-SIGNED`, `EXPIRES`, `DAYS LEFT` and `CIPHER GRADE` (weakest cipher found by `ssl-enum-ciphers`).

- Skipped when the service scan found no TLS ports, or did not run. With reports enabled, `certificates.md` then says `skipped: <reason>`
- Tagged `lan-scan-tls`

## Markdown Reports

When the play sets `netaudit_reports: true` (the Netaudit playbook does), the role also writes its findings as markdown reports to `{{ tls_certificates_report_dir }}` (default: `{{ netaudit_reports_dir }}/tls_certificates`, i.e. `target/netaudit/tls_certificates/` in the repository root). The console output stays the same.

- `certificates.md`: TLS certificates

The reports are written on the Ansible controller by the shared `netaudit/report` helper (`delegate_to: localhost`, without `become`, so the files belong to the user running the playbook). Each report states its status: `completed` (with the number of findings, or "No findings" for an empty result), `failed: <error>` when the scan failed (the role then fails as well) or `skipped: <reason>`. Reports of scans that did not run in this playbook run are not written.

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                            | Description                       | Default                                                                                                            |
|-------------------------------------|-----------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `{{ tls_certificates_ports }}`      | Comma-separated TLS ports to scan | TLS ports from `service_detection_scan`                                                                            |
| `{{ tls_certificates_report }}`     | Write markdown reports            | `{{ netaudit_reports }}` if set, otherwise `false`                                                                 |
| `{{ tls_certificates_report_dir }}` | Directory of the markdown reports | `{{ netaudit_reports_dir }}/tls_certificates`, otherwise `target/netaudit/tls_certificates` in the repository root |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
