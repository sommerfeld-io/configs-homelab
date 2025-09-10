# Raspberry Pi Nodes - Setup Guide

Ubuntu Server is the operating system of choice for all RasPi Nodes.

| RasPi Node | Description                                                  |
| ---------- | ------------------------------------------------------------ |
| `admin-pi` | Run Prometheus, Grafana, Loki and other administrative tools |

## Installation and Configuration

- [ ] Use the RasPi Imager to install Ubuntu Server onto a SD card.
- [ ] Set `sebastian` as user and set the default password.
- [ ] Configure hostname, Wifi settings and enable SSH server with password-based auth.
- [ ] Insert the SD card into the Raspberry Pi and power it on.
- [ ] Connect to new Raspberry Pi via `ssh sebastian@THE_HOSTNAME.fritz.box` from all relevant machines.
- [ ] Setup password-less ssh connections via `ssh-copy-id sebastian@THE_HOSTNAME.fritz.box` from all relevant machines.
- [ ] Install machine using the Ansible configs from this repo using `task`.
    - [ ] [Playbook "raspi"](../../ansible/raspi.md)
    - [ ] [Playbook "repositories"](../../ansible/repositories.md)
    - [ ] [Playbook "telemetry"](../../ansible/telemetry.md)

## Follow-Up Todos

- [ ] Add the new RasPi Node to `components/ansible/assets/global-taskfile.yml` for easy SSH connections.
- [ ] Allow machine to work with GitHub. Use public key `id_rsa.pub`, NOT the private key!
