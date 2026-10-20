# Role: Netaudit TLS Certificates

Lists the TLS certificates on the network with issuer, expiry and cipher grade.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Ping playbook (`configs-homelab/ansible/playbooks/ping.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -sV --script ssl-cert,ssl-enum-ciphers --open -T4` against `{{ subnet }}` on all TLS ports found by the `service_detection` role, and prints `IP`, `HOSTNAME`, `PORT`, `SUBJECT`, `ISSUER`, `SELF-SIGNED`, `EXPIRES`, `DAYS LEFT` and `CIPHER GRADE` (weakest cipher found by `ssl-enum-ciphers`).

- Skipped when the service scan found no TLS ports, or did not run
- Tagged `lan-scan-tls`

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                       | Description                       | Default                                 |
|--------------------------------|-----------------------------------|-----------------------------------------|
| `{{ tls_certificates_ports }}` | Comma-separated TLS ports to scan | TLS ports from `service_detection_scan` |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
