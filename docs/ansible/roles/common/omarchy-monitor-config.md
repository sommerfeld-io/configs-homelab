# Role: Omarchy Monitor Config

Hyprland monitor layout and workspace pinning for Omarchy (Arch/Hyprland) workstations.

The role is intended to be included on every machine (like the other roles in `../common`), but all tasks run inside a `block` guarded by `when: ansible_facts['os_family'] == "Archlinux"`. This makes the role a no-op on Ubuntu/RasPi hosts, so it can safely run in the same playbook as non-Arch machines and does not need to be excluded there.

## What it does

Adds an ansible-managed block to `~/.config/hypr/monitors.lua` (only if the file exists, i.e. on actual Hyprland hosts) that arranges the screens left to right and pins workspaces to them:

| Position | Screen                     | Output                                     | Workspace |
|----------|----------------------------|--------------------------------------------|-----------|
| Left     | Dell UP2716D               | `desc:Dell Inc. DELL UP2716D KRXTR69IASPL` | `1`       |
| Middle   | Dell S3422DWG (curved)     | `desc:Dell Inc. DELL S3422DWG B9BSS63`     | `2`       |
| Right    | Laptop screen              | `eDP-1`                                    | `3`       |

A backup of `monitors.lua` is created whenever the block changes. On change, a handler reloads Hyprland (as `{{ default_user }}`) via `hyprctl reload` and prints `hyprctl configerrors`. The handler exits cleanly when no Hyprland session is running.

## Expected Variables

| Variable             | Description                                                           |
|----------------------|-----------------------------------------------------------------------|
| `{{ default_user }}` | The user to install and configure for (typically the logged-in user) |

## Optional Variables

The following variables are optional and have default values:

| Variable                                         | Description                          |
|--------------------------------------------------|--------------------------------------|
| `{{ common_omarchy_monitor_config_hypr_monitors_file }}` | Path to the Hyprland monitors config |
