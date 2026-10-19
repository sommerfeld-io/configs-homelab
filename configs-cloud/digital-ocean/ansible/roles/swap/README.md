# Role: Swap

This role adds a swap file to the droplet. A 1 GB droplet has no swap by default, so memory pressure would kill processes silently. It is applied by `provision.yml`, before cAdvisor and Alloy start.

The role creates the swap file once with `fallocate`, restricts it to mode `0600`, formats it with `mkswap` and enables it with `swapon`. Formatting and enabling only run when the file is not active yet, so a second run reports no change. An `/etc/fstab` entry keeps the swap file active after a reboot.

The role has no Molecule scenario: `swapon` needs a privileged container, and test containers are never privileged. It is checked on the droplet, where a second provision run reports no change.

## Default Variables

| Variable            | Default     | Description                     |
|---------------------|-------------|---------------------------------|
| `swap_file_path`    | `/swapfile` | Path of the swap file           |
| `swap_file_size_mb` | `1024`      | Size of the swap file in MiB    |
