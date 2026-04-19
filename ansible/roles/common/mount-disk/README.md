# Role: Mount HDD

This role mounts a HDD to a Linux file system

## Required Variables

| Variable                | Description                                                          |
|-------------------------|----------------------------------------------------------------------|
| `{{ ansible_user }}`    | The user to install and configure for (typically the logged-in user) |
| `{{ mount_disk_path }}` | The path to mount the drive to                                       |
| `{{ mount_disk_uuid }}` | The UUID to mount                                                    |
