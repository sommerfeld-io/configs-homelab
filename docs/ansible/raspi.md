# Ansible Playbook - RasPi

This Ansible playbook configures all Raspberry Pi nodes in the home lab infrastructure with essential system components and services, while providing specialized administrative capabilities to the [`admin-pi`](../nodes/raspi/admin-pi.md) node.

The playbook establishes a standardized base configuration across all Raspberry Pi devices and transforms the `admin-pi` into the central management hub for the entire infrastructure.

## What it does

- **Base System Configuration**: Sets up essential system components including shell environment, filesystem structure, package management, and development tools across all Raspberry Pi nodes
- **Container Platform**: Installs and configures Docker for containerized application deployment on all Pi devices
- **Command Line Enhancement**: Configures improved console experience with Bash customizations
- **Administrative Hub Setup**: Transforms the `admin-pi` into a management center with Ansible automation capabilities for infrastructure orchestration
- **Monitoring Infrastructure**: Deploys the complete [telemetry](https://github.com/sommerfeld-io/telemetry) monitoring stack exclusively on the `admin-pi` for centralized observability

The playbook targets all Raspberry Pi nodes for base configuration while specifically enhancing the `admin-pi` with centralized management and monitoring capabilities essential for home lab operations.
