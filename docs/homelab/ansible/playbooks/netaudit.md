# Ansible Playbook - Netaudit

This Ansible playbook scans the homelab network with nmap: which devices are on the network, which services and operating systems they run, which web services, TLS certificates and broadcast services there are, and which inventory hosts are missing. Every role prints its findings to the console and writes them as markdown reports to `target/netaudit/` in the repository root (gitignored).

## Roles

| Role                                                                       | Findings                                                |
|----------------------------------------------------------------------------|---------------------------------------------------------|
| [Netaudit / Nmap](../roles/netaudit/nmap.md)                               | none, installs nmap for the other roles                 |
| [Netaudit / Device Discovery](../roles/netaudit/device-discovery.md)       | devices on the network, missing inventory hosts         |
| [Netaudit / Service Detection](../roles/netaudit/service-detection.md)     | open ports, services and operating systems              |
| [Netaudit / Web Services](../roles/netaudit/web-services.md)               | web services, exposed Docker and Ollama APIs            |
| [Netaudit / TLS Certificates](../roles/netaudit/tls-certificates.md)       | TLS certificates                                        |
| [Netaudit / Broadcast Discovery](../roles/netaudit/broadcast-discovery.md) | DHCP servers, mDNS services, UPnP devices               |
| [Netaudit / Report](../roles/netaudit/report.md)                           | none, renders the console tables and writes the reports |

All roles run on the controller (`localhost`).

## Workflow

```kroki-plantuml
@startuml
autonumber
actor Operator
participant "task homelab:ansible:netaudit" as Task
box "netaudit.yml" #F2F7FC
  participant "Play 1\nGather facts\n(all inventory hosts)" as Facts
  participant "Play 2\nNetwork scan\n(localhost, root)" as Scan
end box
participant "target/netaudit/\n(controller)" as Reports

Operator -> Task : run (optional -- -e ... --tags ...)
Task -> Facts : ansible-playbook playbooks/netaudit.yml
Facts -> Facts : facts for the distribution column\n(unreachable hosts don't stop the run)
Facts -> Scan
Scan -> Scan : nmap, device_discovery,\nservice_detection, web_services,\ntls_certificates, broadcast_discovery
Scan -> Reports : <role>/<finding>.md (console output as well)
@enduml
```

## Running the audit

Run it on the machine you work on (the controller), not in the devcontainer, which only sees the Docker network. The task works from anywhere in the repository:

```bash
task homelab:ansible:netaudit
```

The task uses the shared Ansible task of `configs-homelab/ansible/taskfile.yml`: it updates the submodules and runs `ansible-playbook "playbooks/netaudit.yml" --inventory hosts.yml --ask-become-pass --ask-vault-pass`. Everything after `--` is passed to `ansible-playbook`.

- **Become password:** nmap needs root on the controller for ARP discovery (MAC addresses), OS detection and broadcasts.
- **Vault password:** asked by the shared task; the playbook itself doesn't use vault variables.
- **SSH:** Play 1 connects to the inventory hosts over SSH to gather their facts, like every other homelab playbook.

### Targets and options

| Goal                                     | Command                                                                                    |
|------------------------------------------|--------------------------------------------------------------------------------------------|
| Full audit                               | `task homelab:ansible:netaudit`                                                            |
| Scan another subnet                      | `task homelab:ansible:netaudit -- -e subnet=192.168.178.0/24`                              |
| Only the broadcast discovery             | `task homelab:ansible:netaudit -- --tags lan-scan-broadcast`                               |
| Skip the slow service scan (and web/TLS) | `task homelab:ansible:netaudit -- --skip-tags lan-scan-services,lan-scan-web,lan-scan-tls` |
| Write the reports somewhere else         | `task homelab:ansible:netaudit -- -e netaudit_reports_dir=/tmp/netaudit`                   |
| Console output only, no reports          | `task homelab:ansible:netaudit -- -e netaudit_reports=false`                               |

- `subnet` defaults to the subnet of the controller's default route. The scans only scan this subnet; nothing else is scanned unless you pass it.
- Tags: `lan-scan-services`, `lan-scan-web`, `lan-scan-tls`, `lan-scan-broadcast`. The device discovery has no tag and runs whenever no `--tags` are given. The web and TLS scans take their ports from the service scan, which therefore also runs with `--tags lan-scan-web` or `--tags lan-scan-tls`.

### Platform limits

- The roles run on the controller and only see its network.
- The service scan needs nmap's `--top-ports`, which is broken in nmap 7.992 on Arch Linux; on an affected controller the service detection fails (with a failed report) and stops the scan play.

## Markdown reports

| Variable               | Default in roles                         | Set by the playbook to                        |
|------------------------|------------------------------------------|-----------------------------------------------|
| `netaudit_reports`     | `false` (console output only)            | `true`                                        |
| `netaudit_reports_dir` | `target/netaudit` in the repository root | `{{ playbook_dir }}/../../../target/netaudit` |

Both are play-level variables that every netaudit role respects (each role maps them to its own `<role>_report` and `<role>_report_dir`). The directory is on the Ansible controller and derived from the location of the playbook (or role), not from the working directory, so `task homelab:ansible:netaudit` always writes to `<repository>/target/netaudit/`. A relative `-e netaudit_reports_dir=...` is relative to the working directory of `ansible-playbook` (`configs-homelab/ansible` when run via the task).

```text
target/netaudit/
├── broadcast_discovery/dhcp-servers.md
├── broadcast_discovery/mdns-upnp-devices.md
├── device_discovery/devices.md
├── device_discovery/missing-inventory-hosts.md
├── service_detection/open-ports.md
├── service_detection/operating-systems.md
├── tls_certificates/certificates.md
└── web_services/web-services.md
```

Reports of the previous run are overwritten. A report is only written when its scan runs, so with `--tags` only the selected reports are updated; check the date in each report. Example (`device_discovery/devices.md`, with sample data):

```markdown
# Devices

All devices on the network with MAC address, hostname, state of SSH, HTTP and HTTPS, Raspberry Pi detection, inventory membership and MAC vendor.

- **Tool:** netaudit role `device_discovery`
- **Status:** completed, 3 finding(s)
- **Target host:** `localhost`
- **Scope:** subnet `192.168.178.0/24`
- **Date:** 2026-10-20T21:11:59Z

## Findings

| IP             | MAC               | HOSTNAME           | SSH      | HTTP   | HTTPS  | PI  | INVENTORY | VENDOR               |
|----------------|-------------------|--------------------|----------|--------|--------|-----|-----------|----------------------|
| 192.168.178.1  | 3C:A6:2F:11:22:33 | fritz.box          | closed   | open   | open   |     |           | AVM GmbH             |
| 192.168.178.9  | 00:11:22:33:44:55 | -                  | filtered | -      | -      |     |           | Unknown              |
| 192.168.178.20 | DC:A6:32:AA:BB:CC | pi4-0002.fritz.box | open     | closed | closed | yes | yes       | Raspberry Pi Trading |
```

## Interpreting results

- **Status `completed`:** the scan ran. "No findings" means the scan completed and found nothing, e.g. no open TLS ports.
- **Status `failed: <error>`:** the scan could not run (e.g. missing root, nmap error). The role fails as well, so the run ends with a failure; fix the cause and run again. Not a clean result.
- **Status `skipped: <reason>`:** the scan had nothing to do (e.g. the service scan found no TLS ports). Not a clean result either.
- **Unreachable hosts:** Play 1 ignores them, so the network scan still runs (their distribution column shows `-`). Hosts that are switched off appear in `missing-inventory-hosts.md`.
- **False positives:** nmap service and OS detection are guesses (versions and OS ranges can be wrong), and vendors come from MAC prefixes (random MACs show as unknown). See the role pages for details.

## Tests

The `netaudit` Molecule scenario (`configs-homelab/tests/molecule/netaudit/`) tests all netaudit roles in Ubuntu containers without scanning anything: a stub for `nmap` in `/usr/local/bin` prints canned sample output, while the real nmap package is still installed. Converge runs all roles twice, once with reports disabled and once enabled; verify checks that nmap is installed, that the disabled run wrote no reports and that every report contains the expected findings. Idempotence is checked as well (the report tasks are excluded, they contain the date).

```bash
task homelab:molecule:test:netaudit
```

In CI, the `molecule` job of `.github/workflows/pipeline.yml` runs the scenario (matrix entry `configs-homelab/tests/molecule/netaudit`), see [Pipelines](../../../pipelines.md).
