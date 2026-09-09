# Ansible Playbook - Desktop

This Ansible playbook performs comprehensive setup and configuration of desktop workstations in the home lab environment, transforming them into fully-featured development and administrative machines.

It targets both [Ubuntu Desktop](../../nodes/ubuntu-workstations/index.md) and [Omarchy](../../nodes/omarchy-workstations/index.md) workstations. The shared roles branch internally on `os_family` (`apt`/Debian vs. `pacman`/Archlinux), so both platforms are provisioned to the same feature set from this one playbook.

The playbook handles both system-level configuration requiring elevated privileges and user-specific customizations to create a standardized, secure, and productive desktop environment.

## What it does

- **Security Hardening**: Applies security configurations and hardening measures to protect the system
- **Development Environment**: Installs and configures essential development tools
- **Shell Enhancement**: Sets up improved Bash configurations
- **Virtualization Support**: Enables virtualization capabilities for running virtual machines and containers
- **Task Automation**: Installs utilities for simplified task execution and sets up automated cron jobs
- **File System Management**: Creates standardized directory structures and file system configurations
- **Package Management**: Installs essential system and desktop packages via `apt` (Ubuntu) or `pacman` (Omarchy)

The playbook targets desktop workstations to establish a complete, standardized development and administrative environment suitable for home lab operations and software development activities.

## Known gaps

- **Virtualization**: VirtualBox/Vagrant installation is currently Debian/`apt`-only upstream in `ansible-roles-collection` (Arch support is temporarily disabled pending [ansible-roles-collection#34](https://github.com/sommerfeld-io/ansible-roles-collection/issues/34)), so the `virtualization` role is a no-op on Omarchy for now.
