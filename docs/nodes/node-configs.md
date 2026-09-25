# Node Configs

<!--
  This file is generated automatically by the "ping" Ansible playbook
  (ansible/playbooks/ping.yml). Manual edits will be overwritten the
  next time the playbook runs.
-->

Last generated: 2026-09-25 12:12 UTC

## Fleet Overview

| Hostname             | Groups                | Primary IP      | OS        | OS Version       |
|----------------------|-----------------------|-----------------|-----------|------------------|
| caprica.fritz.box    | ollama, ubuntu_server | 192.168.178.200 | Ubuntu    | 26.04 (resolute) |
| kobol.fritz.box      | ollama, omarchy       | n/a             | n/a       | n/a              |
| pi4-0002.fritz.box   | raspi                 | 192.168.178.22  | Ubuntu    | 26.04 (resolute) |
| pi4-0005.fritz.box   | raspi                 | n/a             | n/a       | n/a              |
| pi4-0006.fritz.box   | raspi                 | n/a             | n/a       | n/a              |
| pi4-dradis.fritz.box | raspi                 | 192.168.178.25  | Ubuntu    | 26.04 (resolute) |
| pi5-0004.fritz.box   | raspi                 | 192.168.178.20  | Ubuntu    | 26.04 (resolute) |
| picon.fritz.box      | ollama, omarchy       | 192.168.178.141 | Archlinux | 4.0.3 (n/a)      |

## Node Details

### `caprica.fritz.box`

- **Groups:** ollama, ubuntu_server
- **Primary IP:** `192.168.178.200` (interface `wlo1`, gateway `192.168.178.1`)
- **Network interfaces:**
    - `eno2` (down): no IP assigned
    - `wlo1`: 192.168.178.200/24 (default route)
- **OS:** Ubuntu 26.04 (resolute)
- **Kernel:** `7.0.0-31-generic`
- **Architecture:** `x86_64`
- **CPU:** Intel(R) Core(TM) i5-10400T CPU @ 2.00GHz (12 vCPUs, 6 cores)
- **Memory:** 15205 MB total / 11499 MB free
- **Root filesystem:** 97.9 GB total / 51.9 GB available
- **Virtualization:** host / kvm
- **Service manager:** `systemd`
- **Facts collected at:** 2026-09-25T12:12:41Z

### `kobol.fritz.box`

- **Groups:** ollama, omarchy
- **Primary IP:** `n/a` (interface `n/a`, gateway `n/a`)
- **Network interfaces:**
    - n/a (host unreachable)
- **OS:** n/a n/a
- **Kernel:** `n/a`
- **Architecture:** `n/a`
- **CPU:** n/a (n/a vCPUs, n/a cores)
- **Memory:** n/a MB total / n/a MB free
- **Root filesystem:** 0.0 GB total / 0.0 GB available
- **Virtualization:** n/a / n/a
- **Service manager:** `n/a`
- **Facts collected at:** n/a

### `pi4-0002.fritz.box`

- **Groups:** raspi
- **Primary IP:** `192.168.178.22` (interface `wlan0`, gateway `192.168.178.1`)
- **Network interfaces:**
    - `eth0` (down): no IP assigned
    - `wlan0`: 192.168.178.22/24 (default route)
- **OS:** Ubuntu 26.04 (resolute)
- **Kernel:** `7.0.0-1019-raspi`
- **Architecture:** `aarch64`
- **CPU:** 3 (4 vCPUs, 1 cores)
- **Memory:** 7796 MB total / 3829 MB free
- **Root filesystem:** 28.7 GB total / 22.7 GB available
- **Virtualization:** host / kvm
- **Service manager:** `systemd`
- **Facts collected at:** 2026-09-25T12:12:44Z

### `pi4-0005.fritz.box`

- **Groups:** raspi
- **Primary IP:** `n/a` (interface `n/a`, gateway `n/a`)
- **Network interfaces:**
    - n/a (host unreachable)
- **OS:** n/a n/a
- **Kernel:** `n/a`
- **Architecture:** `n/a`
- **CPU:** n/a (n/a vCPUs, n/a cores)
- **Memory:** n/a MB total / n/a MB free
- **Root filesystem:** 0.0 GB total / 0.0 GB available
- **Virtualization:** n/a / n/a
- **Service manager:** `n/a`
- **Facts collected at:** n/a

### `pi4-0006.fritz.box`

- **Groups:** raspi
- **Primary IP:** `n/a` (interface `n/a`, gateway `n/a`)
- **Network interfaces:**
    - n/a (host unreachable)
- **OS:** n/a n/a
- **Kernel:** `n/a`
- **Architecture:** `n/a`
- **CPU:** n/a (n/a vCPUs, n/a cores)
- **Memory:** n/a MB total / n/a MB free
- **Root filesystem:** 0.0 GB total / 0.0 GB available
- **Virtualization:** n/a / n/a
- **Service manager:** `n/a`
- **Facts collected at:** n/a

### `pi4-dradis.fritz.box`

- **Groups:** raspi
- **Primary IP:** `192.168.178.25` (interface `eth0`, gateway `192.168.178.1`)
- **Network interfaces:**
    - `eth0`: 192.168.178.25/24 (default route)
    - `wlan0`: 192.168.178.24/24
- **OS:** Ubuntu 26.04 (resolute)
- **Kernel:** `7.0.0-1017-raspi`
- **Architecture:** `aarch64`
- **CPU:** 3 (4 vCPUs, 1 cores)
- **Memory:** 7796 MB total / 2348 MB free
- **Root filesystem:** 56.8 GB total / 49.2 GB available
- **Virtualization:** host / kvm
- **Service manager:** `systemd`
- **Facts collected at:** 2026-09-25T12:12:44Z

### `pi5-0004.fritz.box`

- **Groups:** raspi
- **Primary IP:** `192.168.178.20` (interface `wlan0`, gateway `192.168.178.1`)
- **Network interfaces:**
    - `eth0` (down): no IP assigned
    - `wlan0`: 192.168.178.20/24 (default route)
- **OS:** Ubuntu 26.04 (resolute)
- **Kernel:** `7.0.0-1019-raspi`
- **Architecture:** `aarch64`
- **CPU:** 3 (4 vCPUs, 1 cores)
- **Memory:** 7931 MB total / 3793 MB free
- **Root filesystem:** 56.8 GB total / 49.5 GB available
- **Virtualization:** host / kvm
- **Service manager:** `systemd`
- **Facts collected at:** 2026-09-25T12:12:41Z

### `picon.fritz.box`

- **Groups:** ollama, omarchy
- **Primary IP:** `192.168.178.141` (interface `wlp9s0`, gateway `192.168.178.1`)
- **Network interfaces:**
    - `enp0s13f0u3u1u2` (down): no IP assigned
    - `enp0s31f6` (down): no IP assigned
    - `wlp9s0`: 192.168.178.141/24 (default route)
    - `wwan0` (down): no IP assigned
- **OS:** Archlinux 4.0.3 (n/a)
- **Kernel:** `7.2.3-arch1-3`
- **Architecture:** `x86_64`
- **CPU:** 11th Gen Intel(R) Core(TM) i7-1165G7 @ 2.80GHz (8 vCPUs, 4 cores)
- **Memory:** 31748 MB total / 10860 MB free
- **Root filesystem:** 951.9 GB total / 815.5 GB available
- **Virtualization:** host / kvm
- **Service manager:** `systemd`
- **Facts collected at:** 2026-09-25T12:12:47Z
