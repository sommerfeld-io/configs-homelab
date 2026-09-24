# Role: Omarchy Snapshot

Creates a btrfs snapshot of an Omarchy (Arch/Hyprland) workstation via [snapper](https://github.com/openSUSE/snapper) before the rest of the desktop playbook changes anything. If a playbook run breaks the system, it can be rolled back to the state right before that run.

The role is intended to be included on every machine (like the other roles in `../omarchy`), but all tasks run inside a `block` guarded by `when: ansible_facts['os_family'] == "Archlinux"`. This makes the role a no-op on Ubuntu/RasPi hosts, so it can safely run in the same playbook as non-Arch machines and does not need to be excluded there. The role also skips hosts without `snapper` (e.g. vanilla Arch or test containers) and any snapper config from `{{ omarchy_snapshot_configs }}` that doesn't exist.

## What it does

Omarchy installs on btrfs and ships snapper with a `root` (`/`) and a `home` (`/home`) config. For each existing config the role creates a snapshot, but only if the most recent snapshot created by this role is at least `{{ omarchy_snapshot_min_interval_hours }}` hours (default: 24, i.e. one day) old - or if there is none yet:

```bash
snapper -c <config> create --description "{{ omarchy_snapshot_description }}" --cleanup-algorithm number --print-number
```

- **One snapshot per day:** running the playbook several times in direct succession (e.g. while iterating on a role) doesn't create a new snapshot every time. Within the interval, the existing snapshot is kept as the rollback point, so it still reflects the state before the *first* run of the day - usually the last known-good state.
- **Only this role's snapshots count:** they are matched by their description (`{{ omarchy_snapshot_description }}`). The automatic pre/post snapshots Omarchy creates around every `pacman` transaction are ignored, otherwise they would almost always be "recent" and suppress the snapshot.
- The age check compares snapshot dates in UTC (`snapper --utc`) with the target's fact time, so timezones don't matter.
- The role is run by the Omarchy Snapshot Create playbook (`ansible/playbooks/omarchy-snapshot-create.yml`), which is imported at the very top of the desktop playbook, so the snapshot captures the system state before any other role runs. To take a snapshot on its own, run `task ansible:omarchy:snapshot:create`.
- The created snapshot numbers are printed in the playbook output. Note them down in case you need to roll back.
- Snapshots use snapper's `number` cleanup algorithm, so snapper's regular cleanup prunes old ones and a snapshot per playbook run doesn't fill up the disk.
- On Omarchy, `limine-snapper-sync` picks up new `root` snapshots and adds them to the Limine boot menu, which makes them bootable.

The create task reports `changed` whenever it creates a snapshot and is skipped otherwise - see [When no new snapshot is created](#when-no-new-snapshot-is-created) for all cases.

## When no new snapshot is created

The role creates a snapshot per snapper config on every run, except in these cases:

| Situation                                                                                                                     | Result                                                                                                 |
|-------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| Host is not Arch (Ubuntu, RasPi)                                                                                              | Nothing happens, the role is a no-op                                                                   |
| `snapper` isn't installed (`/usr/bin/snapper` missing)                                                                        | No snapshot on that host                                                                               |
| A config from `{{ omarchy_snapshot_configs }}` doesn't exist (`/etc/snapper/configs/<config>` missing)                        | No snapshot for that config, the other configs are still snapshotted                                   |
| The most recent snapshot created by this role is younger than `{{ omarchy_snapshot_min_interval_hours }}` hours (default: 24) | No snapshot for that config; the existing one stays the rollback point                                 |
| Playbook runs in check mode (`--check`)                                                                                       | No snapshot; the snapshots aren't even listed, so check mode can't tell whether a run would create one |
| Host is unreachable, or not in the `omarchy` inventory group                                                                  | No snapshot, since the role doesn't run there                                                          |

How the interval check works in detail:

- **Rolling 24 hours, not calendar days:** the age is measured from the most recent snapshot's creation time. A snapshot taken on Monday at 09:00 blocks new snapshots until Tuesday 09:00 - running the playbook again on Monday at 23:00 or Tuesday at 08:00 creates none, while a run on Tuesday at 09:05 does.
- **Per config:** `root` and `home` are checked independently. If one of them has no recent snapshot (e.g. because its snapshot was deleted), only that one gets a new snapshot.
- **Only this role's snapshots count:** the automatic pre/post snapshots around `pacman` transactions, snapper timeline snapshots and manually created snapshots never block a new snapshot, because they have a different description.
- **Deleting a snapshot resets the interval:** if the most recent snapshot created by this role is deleted, the next run compares against the one before it - or creates a new one right away if there is none left.
- **Changing the description resets the interval:** snapshots are matched by `{{ omarchy_snapshot_description }}`, so after changing it, older snapshots no longer count and the next run creates a new one.

To force a new snapshot anyway (e.g. right before trying something risky), run with `-e omarchy_snapshot_min_interval_hours=0`.

## Rollback

Find the snapshot to roll back to first. Its description is `{{ omarchy_snapshot_description }}` and its number was printed in the playbook output of the run that created it. Because of the daily interval, this may be an earlier run than the one that broke the system. List all snapshots of all Omarchy workstations with `task ansible:omarchy:snapshot:list` (the Omarchy Snapshot List playbook), or directly on the workstation:

```bash
sudo snapper -c root list
sudo snapper -c home list
```

### System no longer boots (or the desktop is unusable)

1. Reboot the machine.
2. In the Limine boot menu, open the snapshots entry and select the snapshot from the broken playbook run (match number/date with the playbook output).
3. Boot into the snapshot and check that the system works as expected.
4. Make the rollback permanent by restoring the snapshot, then reboot:

    ```bash
    sudo limine-snapper-restore
    ```

This only restores `/` (the `root` config). If the playbook also broke files under `/home`, revert them afterwards as described below.

### System still boots

Revert the changes made since the snapshot in place, without rebooting into it. Replace `<N>` with the snapshot number:

```bash
sudo snapper -c root status <N>..0      # show what changed since the snapshot
sudo snapper -c root undochange <N>..0  # revert those changes
sudo snapper -c home undochange <N>..0  # same for /home, if needed
```

Reboot afterwards, so services and the Hyprland session pick up the reverted files.

> **:bulb: NOTE:** `undochange` reverts files, it doesn't restore the whole subvolume. For a badly broken system, prefer booting into the snapshot as described above.

### Delete a snapshot

Snapshots are pruned automatically, but a snapshot can also be removed manually:

```bash
sudo snapper -c root delete <N>
```

## Optional Variables

The following variables are optional and have default values:

| Variable                                           | Description                                                                                      | Default                                |
|----------------------------------------------------|--------------------------------------------------------------------------------------------------|----------------------------------------|
| `{{ omarchy_snapshot_configs }}`            | snapper configs to snapshot (skipped when missing)                                               | `root`, `home`                         |
| `{{ omarchy_snapshot_description }}`        | Description of the created snapshots                                                             | `ansible: before desktop playbook run` |
| `{{ omarchy_snapshot_min_interval_hours }}` | Minimum age (hours) of the most recent snapshot created by this role before a new one is created | `24`                                   |
