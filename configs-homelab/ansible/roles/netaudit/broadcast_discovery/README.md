# Role: Netaudit Broadcast Discovery

Finds devices and services that announce themselves via broadcasts and never show much in a port scan, and detects rogue DHCP servers.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Ping playbook (`configs-homelab/ansible/playbooks/ping.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap --script broadcast-dhcp-discover,broadcast-dns-service-discovery,broadcast-upnp-info` on the interface of the default route and prints two tables:

- **DHCP servers:** `SERVER`, `OFFERED IP`, `ROUTER`, `DNS`, `DOMAIN`. Warns if more than one DHCP server answers
- **mDNS services and UPnP devices:** `IP`, `HOSTNAME`, `PROTOCOL`, `SERVICE / DEVICE`, `DETAILS` (model for mDNS, manufacturer and model for UPnP). Hostnames come from the `device_discovery` scan
- Tagged `lan-scan-broadcast`

The role uses no subnet, broadcasts reach the local network of the default interface only.

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
