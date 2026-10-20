# Role: Netaudit Nmap

Installs nmap, the scanner all other netaudit roles use. Every other netaudit role declares this role as a dependency in its `meta/main.yml`, so it runs once per play before the first of them.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Ping playbook (`configs-homelab/ansible/playbooks/ping.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

- Installs the `nmap` package with the distribution's package manager (Ubuntu and Arch Linux)
- The task is tagged `always`, so nmap is also installed when only single scans are selected with `--tags`

The role has no variables.
