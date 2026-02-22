# Ansible Playbook - RasPi

This Ansible playbook configures all Raspberry Pi nodes in the home lab infrastructure with essential system components and services. It establishes a standardized base configuration across all Raspberry Pi devices.

## What it does

- **Base System Configuration**: Sets up essential system components including shell environment, filesystem structure, package management, and development tools across all Raspberry Pi nodes
- **Container Platform**: Installs and configures Docker for containerized application deployment on all Pi devices
- **Command Line Enhancement**: Configures improved console experience with Bash customizations
- **Administrative Hub Setup**: Transforms the `admin-pi` into a management center with Ansible automation capabilities for infrastructure orchestration

The playbook targets all Raspberry Pi nodes for base configuration.
