# Ansible Playbook - Ping

This Ansible playbook performs a lightweight connectivity and Python execution check across all nodes in the home lab inventory. It is intended as a quick health check to verify that managed hosts are reachable and ready for further automation tasks.

## What it does

- **Node Reachability Check**: Connects to every configured host in the Ansible inventory
- **Ansible Ping Validation**: Executes `ansible.builtin.ping` to confirm remote module execution works
- **Fact Gathering**: Collects OS, network, and hardware facts from every reachable node
- **Network Scan** (second play, runs on `localhost` with `become: true` because nmap needs root for MAC addresses and OS detection): installs `nmap` and scans the local subnet (auto-detected from the default route, override with `-e lan_scan_subnet=192.168.178.0/24`)
    - **Device overview**: IP, MAC, hostname, state of SSH (22), HTTP (80) and HTTPS (443), whether the device is a Raspberry Pi (by MAC vendor prefix), whether it is part of the Ansible inventory (`INVENTORY`), and the MAC vendor
    - **Missing inventory hosts**: inventory hosts that did not show up in the scan
    - **Services**: open ports with service name and version for the top 100 ports (`lan_scan_top_ports`) of every device. This takes a few minutes
    - **Operating systems**: per device the Linux distribution and version from the Ansible facts gathered by the first play (inventory hosts only, because nmap fingerprints the kernel but cannot tell distributions apart) and the OS nmap detects or guesses
    - **Web services and exposed APIs** (tag `lan-scan-web`): HTTP title and server header of every HTTP(S) port found by the service scan, plus Ollama (`11434`) and Docker API (`2375`, `2376`). Warns about a Docker API without TLS and an Ollama API reachable without authentication
    - **TLS certificates** (tag `lan-scan-tls`): subject, issuer, self-signed yes/no, expiry date, days left and weakest cipher grade of every TLS port found by the service scan
    - **Broadcast discovery** (tag `lan-scan-broadcast`): DHCP servers that answer a DHCP discover (warns if more than one does), services announced via mDNS (AirPlay, SSH, printers, ...) and UPnP devices with manufacturer and model

Single scans can be run with `--tags`, e.g. `--tags lan-scan-broadcast`, or skipped with `--skip-tags`. The web and TLS scans take their ports from the service scan (tag `lan-scan-services`), which therefore also runs with `--tags lan-scan-web` or `--tags lan-scan-tls`.

The playbook targets all inventory nodes to provide a simple, centralized operational readiness check for the full home lab.
