# Role: Netaudit Device Discovery

Lists all devices on the network and the inventory hosts that did not show up in the scan.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Ping playbook (`configs-homelab/ansible/playbooks/ping.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -p 22,80,443` against `{{ subnet }}` and prints one line per device:

| Column      | Content                                                                       |
|-------------|-------------------------------------------------------------------------------|
| `IP`        | IP address                                                                    |
| `MAC`       | MAC address (the own MAC from Ansible facts for the machine running the scan) |
| `HOSTNAME`  | Hostname from reverse DNS                                                     |
| `SSH`       | State of port 22 (`open`, `closed`, `filtered`)                               |
| `HTTP`      | State of port 80                                                              |
| `HTTPS`     | State of port 443                                                             |
| `PI`        | `yes` if the MAC vendor prefix belongs to Raspberry Pi                        |
| `INVENTORY` | `yes` if the hostname is part of the Ansible inventory                        |
| `VENDOR`    | MAC vendor, `(this machine)` for the machine running the scan                 |

Afterwards it prints the inventory hosts that are missing from the scan result.

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                            | Description                                                            | Default                                         |
|-------------------------------------|------------------------------------------------------------------------|-------------------------------------------------|
| `{{ device_discovery_raspi_ouis }}` | Regex of MAC prefixes (OUIs) and vendor names that mark a Raspberry Pi | Raspberry Pi Foundation / Raspberry Pi Ltd OUIs |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
