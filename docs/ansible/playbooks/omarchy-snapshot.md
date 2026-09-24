# Ansible Playbook - Omarchy Snapshot

This Ansible playbook creates a btrfs snapshot (via snapper) of the [Omarchy](../../nodes/omarchy-workstations/index.md) workstations, so a workstation can be rolled back if a later playbook run breaks the system.

It is imported at the very top of the [desktop playbook](./desktop.md), so every desktop run takes the snapshot before anything is changed. Run it on its own with `task ansible:omarchy:snapshot`, e.g. before trying something risky by hand.

## What it does

- **Snapshot**: Runs the [Omarchy Snapshot role](../roles/omarchy/snapshot.md) on all hosts of the `omarchy` inventory group, which snapshots `/` and `/home`
- **At most once per day**: A new snapshot is only created if the most recent snapshot created by the role is at least a day old, so running the playbook (or the desktop playbook) several times in a row doesn't pile up snapshots

The playbook only needs `sudo` (for snapper), not the Ansible vault, so the task only prompts for the become password. To force a new snapshot within the day, pass the interval as an extra variable:

```bash
ansible-playbook playbooks/omarchy-snapshot.yml --inventory hosts.yml --ask-become-pass -e omarchy_snapshot_min_interval_hours=0
```

See the [Omarchy Snapshot role](../roles/omarchy/snapshot.md) for how to roll back to a snapshot.
