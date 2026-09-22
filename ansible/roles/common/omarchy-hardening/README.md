# Role: Omarchy Hardening

Omarchy (Arch/Hyprland) specific hardening to close gaps that `inspec:run:*` reports
against the [`desktop-baseline`](../../../../tests/inspec/desktop-baseline) InSpec
profile (`dev-sec/linux-baseline`) on Omarchy hosts, which the pre-installed Arch
`shadow`/`filesystem` packages don't close out of the box.

The role is intended to be included on every machine (like the other roles in
`../common`), but all tasks run inside a `block` guarded by
`when: ansible_facts['os_family'] == "Archlinux"`. This makes the role a no-op on
Ubuntu/RasPi hosts, so it can safely run in the same playbook as non-Arch machines
and does not need to be excluded there.

`tasks/main.yml` only imports further task files - one subfolder per hardening
concern, each with its own tasks.

## Hardening

### login.defs (`login-defs`)

Arch's `shadow` package ships `/etc/login.defs` without `PASS_MAX_DAYS`,
`PASS_MIN_DAYS` or `PASS_WARN_AGE` at all, and with an `ENV_SUPATH`/`ENV_PATH` that's
missing `/usr/sbin`, `/sbin` and `/bin` compared to what `linux-baseline`'s `os-13`
control expects. `common_omarchy_hardening_login_defs` (see
[`defaults/main.yml`](defaults/main.yml)) lists the key/value pairs written into
`/etc/login.defs` to close this gap.

### Mount Options (`mount-options`)

`linux-baseline`'s `os-15`/`os-16` controls expect `nosuid`/`nodev` on mountpoints
that don't need to allow device nodes or setuid/setgid binaries -
`common_omarchy_hardening_hardened_mountpoints` (default: `/boot`, `/home`,
`/var/log`) lists them. For each one, the task reads its current device/fstype/
options straight out of `ansible_facts.mounts`, adds `nosuid`/`nodev` if missing,
and remounts it with the merged options - it never guesses a device or fstype, so a
mountpoint that isn't actually mounted (e.g. inside the Molecule test containers,
where these are just directories on the root filesystem) is safely skipped instead
of guessed at.

> **:warning: NOTE:** This remounts live filesystems on the target host. `nosuid`
> and `nodev` are safe on `/boot`, `/home` and `/var/log` (none of them need to run
> setuid binaries or hold device nodes), but double-check before adding more
> mountpoints here - `nodev` on a mountpoint bind-mounting device nodes, or `nosuid`
> somewhere a setuid binary must run from, would break things.
>
> **:bulb: NOTE:** `linux-baseline`'s `os-16` control also expects the kernel
> parameter `fs.protected_regular` to be `2` (or unset). That part of `os-16` is not
> covered by this role.

## Expected Variables

None.

## Optional Variables

The following variables are optional and have default values - see
[`defaults/main.yml`](defaults/main.yml):

| Variable                                              | Description                                                 |
|-------------------------------------------------------|-------------------------------------------------------------|
| `{{ common_omarchy_hardening_login_defs }}`           | List of `{key, value}` pairs written into `/etc/login.defs` |
| `{{ common_omarchy_hardening_hardened_mountpoints }}` | Mountpoints to add `nosuid`/`nodev` to, if actually mounted |
