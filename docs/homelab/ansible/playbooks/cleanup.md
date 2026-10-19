# Ansible Playbook - Cleanup

This Ansible playbook performs comprehensive system maintenance across Ubuntu desktop workstations and Raspberry Pi nodes in the home lab infrastructure. The playbook removes unnecessary files, cleans up Docker resources, and eliminates outdated Vagrant images to free up disk space and maintain optimal system performance.

## What it does

- **Docker Cleanup**: Removes build caches, stopped containers, unused networks, dangling images, and orphaned volumes
- **Temporary File Cleanup**: Deletes installer files, scripts, and archives from tmp directories
- **Vagrant Maintenance**: Prunes stale Vagrant box images on Ubuntu desktop systems
- **Junk File Removal**: Identifies and removes unwanted directories like `System Volume Information` from user home directories

The playbook targets both Ubuntu desktop workstations and Raspberry Pi nodes.
