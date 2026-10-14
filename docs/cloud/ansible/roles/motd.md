# Role: MOTD

This role replaces the default Ubuntu login banner (MOTD) on the droplet with a DigitalOcean ASCII art banner, an OS line and the pending update count. It is applied by `provision.yml`. See the Provisioning page (`docs/cloud/digital-ocean/provisioning.md`) for the layout and how the banner is built.

## Files

| File                | Installed to                          | Purpose                                                                                  |
|---------------------|---------------------------------------|------------------------------------------------------------------------------------------|
| `files/banner.txt`  | `/usr/local/share/motd/banner.txt`    | The ASCII art, read by `00-banner`                                                       |
| `files/00-banner`   | `/etc/update-motd.d/00-banner`        | Blank line, the art, blank line                                                          |
| `files/10-os-line`  | `/etc/update-motd.d/10-os-line`       | `Welcome to <PRETTY_NAME> (GNU/Linux <kernel> <arch>)`, computed at login                |
| `files/20-updates`  | `/etc/update-motd.d/20-updates`       | Update count from Ubuntu's cached update-notifier stamp, nothing when the count is 0     |

## Why the Scripts Have No `.sh` Extension

At login, `pam_motd` builds the MOTD by running `run-parts --lsbsysinit /etc/update-motd.d`. With `--lsbsysinit`, `run-parts` only runs files whose names are made of letters, digits, `_` and `-`. A name with a dot, like `00-banner.sh`, is silently skipped, so the script would never show up in the banner. Ubuntu's own scripts in that folder (`00-header`, `90-updates-available`, `98-reboot-required`) have no extension for the same reason.

The files in `files/` are named exactly like their targets, because the role copies each one 1:1 to `/etc/update-motd.d/<name>`. `banner.txt` keeps its extension because it is only data that `00-banner` reads; it is not run.

## Variables

The banner art is always installed to the fixed path `/usr/local/share/motd/banner.txt`, which `00-banner` reads.

| Variable            | Default                                    | Description                                                           |
|---------------------|--------------------------------------------|-----------------------------------------------------------------------|
| `motd_dir`          | `/etc/update-motd.d`                       | Folder `pam_motd` runs at login                                       |
| `motd_keep_scripts` | `98-reboot-required`                       | Default scripts that stay executable                                  |
| `motd_scripts`      | `00-banner`, `10-os-line`, `20-updates`    | The role's own scripts in `files/`                                    |
