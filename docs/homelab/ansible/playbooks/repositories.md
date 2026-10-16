# Ansible Playbook - Repositories

This Ansible playbook manages Git repository distribution across the home lab infrastructure by preparing the necessary directory structure and cloning essential repositories to the appropriate nodes. The playbook ensures that Ubuntu desktop workstations have access to the complete set of development repositories, while Raspberry Pi nodes receive only the configuration repositories required for their operational roles.

## What it does

- **Directory Setup**: Creates the required filesystem structure for organizing Git repositories across all target hosts
- **Development Repository Distribution**: Clones the full suite of development repositories to Ubuntu desktop workstations
- **Configuration Management**: Ensures the `admin-pi` has access to the essential configuration repository needed for infrastructure management

The playbook targets Ubuntu desktop systems for comprehensive development repository access and specifically provisions the `admin-pi` with the core configuration repository needed for home lab operations.
