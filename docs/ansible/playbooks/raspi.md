# Ansible Playbook - RasPi

This Ansible playbook configures all Raspberry Pi nodes in the home lab infrastructure with essential system components and services. It establishes a standardized base configuration across all Raspberry Pi devices.

## What it does

- **Base System Configuration**: Sets up essential system components including shell environment, filesystem structure, package management, and development tools across all Raspberry Pi nodes
- **Container Platform**: Installs and configures Docker for containerized application deployment on all Pi devices
- **Command Line Enhancement**: Configures improved console experience with Bash customizations
- **Administrative Hub Setup**: Transforms the `admin-pi` into a management center with Ansible automation capabilities for infrastructure orchestration

The playbook targets all Raspberry Pi nodes for base configuration.

## Fantasy Hockey Cleanup

The fantasy hockey app moved from `pi4-0002` to the DigitalOcean droplet (see [Deployment](../../cloud/digital-ocean/deployment.md)). The last play of `raspi.yml` removes the old deployment from `pi4-0002`: it fails when containers run there that belong neither to the `fantasy-hockey` project nor to the fleet (`cadvisor`, play variable `fantasy_hockey_pi_fleet_containers`), then stops the stack and deletes `/opt/fantasy-hockey` without a backup. The play is tagged `never`, so `task homelab:ansible:raspi` and `task homelab:ansible:all` skip it. Run it once, after the app is verified on the droplet. The task limits the run to `pi4-0002`:

```bash
task homelab:ansible:raspi:fantasy-hockey-cleanup
```
