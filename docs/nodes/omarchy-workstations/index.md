# Omarchy Workstations - Setup Guide

[Omarchy](https://omarchy.org) is one of the operating systems used for workstations, alongside [Ubuntu Desktop](../ubuntu-workstations/index.md). Omarchy is an opinionated, Arch-based Linux distribution built around the Hyprland Wayland compositor.

| Workstation | Description                                                        | OS      |
|-------------|--------------------------------------------------------------------|---------|
| `kobol`     | Backup workstation (laptop) for development tasks and daily to-dos | Omarchy |

> **Disposition tags:** a few steps below carry a `_Disposition: permanently accepted_` note. This describes whether that specific manual step is expected to stay manual forever — not whether you've completed it in this run (the checkbox still tracks that). Only the small set of steps considered part of Homelab Configs' automation boundary carry a tag; every other checklist item here is ordinary one-time physical/OS setup, out of that scope.

## Setup Guide

- [ ] Disable Secure Boot in the BIOS/UEFI settings before booting the installer. Omarchy's kernel/bootloader isn't signed for Secure Boot, so the machine won't boot with it enabled.
- [ ] Run through the Omarchy setup wizard (hostname, user, disk encryption, etc.).
- [ ] Initialize SSH and other mandatory things using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/omarchy.sh | bash -`
- [ ] Setup password-less ssh connections via `ssh-copy-id sebastian@<hostname>.fritz.box` from all relevant machines. Allowing password-less ssh connections is essential for Ansible to work properly. — _Disposition: permanently accepted_
- [ ] Install machine using the Ansible configs from this repo: [Playbook "desktop"](../../ansible/playbooks/desktop.md) (`task ansible:desktop`)
- [ ] [Playbook "repositories"](../../ansible/playbooks/repositories.md)
