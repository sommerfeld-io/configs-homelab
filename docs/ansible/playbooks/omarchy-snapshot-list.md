# Ansible Playbook - Omarchy Snapshot List

This Ansible playbook lists all existing btrfs snapshots (via snapper) of the [Omarchy](../../nodes/omarchy-workstations/index.md) workstations. Run it with `task ansible:omarchy:snapshot:list`, e.g. to find the snapshot to roll back to.

It is imported at the end of the [Omarchy Snapshot Create playbook](./omarchy-snapshot-create.md), so every snapshot run (and therefore every [desktop playbook](./desktop.md) run) also prints the snapshot list.

## What it does

- **List snapshots**: Runs `snapper --iso list --all-configs` on all hosts of the `omarchy` inventory group and prints the result, i.e. the snapshots of all snapper configs (`root` for `/`, `home` for `/home`)
- **All snapshots**: Shows every snapshot, not only the ones created by the [Omarchy Snapshot role](../roles/omarchy/snapshot.md) - also the automatic pre/post snapshots around `pacman` transactions
- **Read-only**: Never changes anything, and also lists the snapshots in check mode (`--check`)
- **Safe on other hosts**: Skips hosts that aren't Arch Linux or don't have `snapper` installed

See the [Omarchy Snapshot role](../roles/omarchy/snapshot.md) for how to roll back to a snapshot.
