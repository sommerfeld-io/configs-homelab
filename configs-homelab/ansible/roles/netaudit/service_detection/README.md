# Role: Netaudit Service Detection

Detects open ports, service versions and operating systems of all devices on the network. Takes a few minutes.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Ping playbook (`configs-homelab/ansible/playbooks/ping.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -sV -O --osscan-guess --top-ports {{ service_detection_top_ports }} --open -T4` against `{{ subnet }}` and prints two tables:

- **Open ports and services:** `IP`, `HOSTNAME`, `PORT`, `SERVICE`, `VERSION`
- **Operating systems:** `IP`, `HOSTNAME`, `DISTRO (ANSIBLE FACTS)`, `OS (NMAP)`. nmap fingerprints the kernel but cannot tell Linux distributions apart, so the distribution and version come from the Ansible facts of the inventory hosts gathered earlier in the same run. Hosts outside the inventory or without facts show `-`

The scan result is registered as `service_detection_scan`. The `web_services` and `tls_certificates` roles take their ports from it, so the tasks are tagged `lan-scan-services`, `lan-scan-web` and `lan-scan-tls`.

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                            | Description                                                                              | Default               |
|-------------------------------------|------------------------------------------------------------------------------------------|-----------------------|
| `{{ service_detection_top_ports }}` | Number of most common ports to scan per device                                           | `100`                 |
| `{{ service_detection_distros }}`   | `host=distribution version|...` list built from the Ansible facts of all inventory hosts | built from `hostvars` |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
