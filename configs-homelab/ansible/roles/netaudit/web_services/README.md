# Role: Netaudit Web Services

Lists the web services on the network with their HTTP title and server header, and flags exposed APIs.

All netaudit roles run on the machine that executes the playbook (`localhost`) and need root (`become: true`), because nmap needs it for ARP discovery (MAC addresses), OS detection and broadcasts. The Ping playbook (`configs-homelab/ansible/playbooks/ping.yml`) runs them in this order: `nmap`, `device_discovery`, `service_detection`, `web_services`, `tls_certificates`, `broadcast_discovery`.

## What it does

Runs `nmap -sV --script http-title,http-server-header --open -T4` against `{{ subnet }}` on all HTTP(S) ports found by the `service_detection` role plus `{{ web_services_extra_ports }}`, and prints `IP`, `HOSTNAME`, `PORT`, `SERVER`, `TITLE` and `WARNING`.

- `WARNING` is set for an open Docker API without TLS (`2375`) and an open Ollama API without authentication (`11434`)
- Without the `service_detection` scan (e.g. skipped with `--skip-tags lan-scan-services`), only the extra ports are scanned
- Tagged `lan-scan-web`

## Required Variables

| Variable       | Description                                                    | Example            |
|----------------|----------------------------------------------------------------|--------------------|
| `{{ subnet }}` | Subnet to scan in CIDR notation, set in the `vars` of the play | `192.168.178.0/24` |

## Optional Variables

The following variables are optional and have default values:

| Variable                         | Description                                                             | Default                                                          |
|----------------------------------|-------------------------------------------------------------------------|------------------------------------------------------------------|
| `{{ web_services_extra_ports }}` | Ports probed in addition to the HTTP(S) ports found by the service scan | `11434` (Ollama), `2375`, `2376` (Docker API)                    |
| `{{ web_services_ports }}`       | Comma-separated ports to scan                                           | HTTP(S) ports from `service_detection_scan` plus the extra ports |

## Dependencies

- `netaudit/nmap` (installs nmap), declared in `meta/main.yml` and run only once per play
