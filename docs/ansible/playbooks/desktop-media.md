# Ansible Playbook - Desktop Media

This Ansible playbook installs and configures `caprica.fritz.box` as a media server, mounting the external storage disks that hold media files and deploying [Jellyfin](https://jellyfin.org) to serve them.

## What it does

- **Disk Mounting**: Mounts the media server's external USB disks (via UUID) to dedicated paths under `/mnt`, adding persistent `fstab` entries
- **Jellyfin**: Deploys the Jellyfin media server as a Docker Compose stack, serving the video library from the mounted disks

The playbook targets `caprica.fritz.box` and is imported automatically as part of `ansible/playbooks/desktop.yml`.
