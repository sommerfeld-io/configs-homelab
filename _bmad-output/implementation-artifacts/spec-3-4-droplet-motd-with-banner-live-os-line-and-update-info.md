---
title: 'Droplet login banner (MOTD) with live OS and update info'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_commit: 'c7aca039c0de223ec2552dda28c87c6aca0fdf47'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The droplet greets operators with Ubuntu's default MOTD (help links, system information, ESM notices), so the host and its update state are hard to see at a glance (CAP-2, Story 3.4).

**Approach:** Extend `provision.yml` with a cloud role `motd` that adds scripts to `/etc/update-motd.d/` printing, in this order: a blank line, the ASCII art below, a blank line, an OS line, a blank line, the update info, a blank line. Stop every other default script from printing, except Ubuntu's own `*** System restart required ***` notice, which stays and shows after the update info. Document it under `docs/cloud/digital-ocean`.

```text
 ___  _      _ _        _  ___
|   \(_)__ _(_) |_ __ _| |/ _ \ __ ___ __ _ _ _
| |) | / _` | |  _/ _` | | (_) / _/ -_) _` | ' \
|___/|_\__, |_|\__\__,_|_|\___/\__\___\__,_|_||_|
       |___/
```

## Boundaries & Constraints

**Always:** OS line form `Welcome to <PRETTY_NAME> (GNU/Linux <kernel release> <architecture>)` computed at login from `/etc/os-release` and `uname`, same format as Ubuntu's own `00-header`. Update info form `<N> updates can be applied immediately.` then `To see these additional updates run: apt list --upgradable`, read at login from Ubuntu's cached stamp `/var/lib/update-notifier/updates-available` (refreshed by Ubuntu's apt hooks after every `apt update` and dpkg run) with the ESM lines left out, never written as static text by Ansible and never by running `apt-check` at login (about 2.8 s of CPU on this droplet). Banner art stored once as a file in the role. A second `provision.yml` run changes nothing in this role. Cloud role under `configs-cloud/digital-ocean/ansible/roles`, folder allowed in `.folderslintrc`. Docs updated in the same change; run every command the docs show once first.

**Never:** No change under `configs-homelab/`. No static `/etc/motd` (it does not exist and `sshd` has `PrintMotd no`; the MOTD comes from `pam_motd` running `/etc/update-motd.d/`). No `tofu apply`. No apt package installs for the banner.

## I/O & Edge-Case Matrix

| Scenario              | Input / State                                | Expected Output / Behavior                                                                                       | Error Handling                   |
|-----------------------|----------------------------------------------|------------------------------------------------------------------------------------------------------------------|----------------------------------|
| Login, updates, no reboot | N updates pending, no reboot-required file | Blank, art, blank, OS line, blank, update info, blank; nothing else                                              | N/A                              |
| Login, reboot pending | `/var/run/reboot-required` exists            | Same layout, then `*** System restart required ***` directly after the trailing blank line                       | N/A                              |
| Login, no updates     | Zero updates pending                         | Blank, art, blank, OS line, blank; no update info block and no extra blank lines                                 | N/A                              |
| Second provision      | Already provisioned                          | `changed=0` for the motd role                                                                                    | N/A                              |
| Kernel change         | New kernel after a reboot                    | OS line shows the new kernel release without re-provisioning                                                     | N/A                              |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- add the `motd` role last (relative `include_role: ../roles/motd`, same style as `swap`).
- `configs-cloud/digital-ocean/ansible/roles/motd/` (new) -- `tasks/main.yml`, `files/banner.txt`, scripts as `files/*` or `templates/*`. Order by file name, e.g. `00-banner`, `10-os-line`, `20-updates`.
- Droplet facts (read-only SSH, Ubuntu 26.04.1): `/etc/update-motd.d/` holds `00-header`, `10-help-text`, `50-landscape-sysinfo` (symlink to `/usr/share/landscape/landscape-sysinfo.wrapper`), `50-motd-news`, `85-fwupd`, `90-updates-available`, `91-contract-ua-esm-status`, `91-release-upgrade`, `92-unattended-upgrades`, `95-hwe-eol`, `97-overlayroot`, `98-fsck-at-reboot`, `98-reboot-required`. `98-reboot-required` stays: it prints `/var/run/reboot-required` (`*** System restart required ***`).
- Disable defaults by removing the exec bit (`pam_motd` runs only executable scripts) on every entry except `98-reboot-required` and the role's own scripts; the symlink `50-landscape-sysinfo` points into a package file, so handle it as a symlink rather than changing the target. Pick the approach that survives a package upgrade and a second run (idempotent), record it. dpkg keeps local changes to these conffiles.
- `/var/lib/update-notifier/updates-available` (the stamp, same text as `apt-check --human-readable`; the helper is `/usr/lib/update-notifier/apt-check`, hyphen, `apt_check` does not exist) holds the ESM notice, `12 updates can be applied immediately.`, `To see these additional updates run: apt list --upgradable`, then ESM lines. Keep only the two update lines (match on `updates can be applied immediately` and `apt list --upgradable`); when neither is present print nothing.
- Current full output on the droplet (before): `run-parts --lsbsysinit /etc/update-motd.d` lists help, system information, ESM and update blocks, then two blank lines and the reboot notice. The stamp ends with a blank line.
- `.folderslintrc` -- add `configs-cloud/*/ansible/roles/motd` and its sub-folders (`tasks`, `files`).
- `docs/cloud/digital-ocean/provisioning.md` (+ `index.md` if it lists provisioned software) -- document the MOTD and how it is built, including how to see it without logging in (`run-parts --lsbsysinit /etc/update-motd.d`).
- Planning facts: none change.

## Tasks & Acceptance

**Execution:**
- [x] `configs-cloud/digital-ocean/ansible/roles/motd/` -- banner file, OS-line and update-info scripts, disable the other defaults -- clean banner
- [x] `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- include the `motd` role -- wiring
- [x] `.folderslintrc` -- allow the new role folders -- folder lint
- [x] `docs/cloud/digital-ocean/provisioning.md` (and `index.md` if needed) -- describe the MOTD and how it is built -- epic docs rule

**Acceptance Criteria:**
- Given `provision.yml` has run, when I log in via SSH, then the MOTD is exactly a blank line, the art, a blank line, the OS line, a blank line, the update info, a blank line, and nothing else except the reboot notice when a reboot is pending.
- Given the OS line and the update info, when I log in, then they come from the running system at login and follow a kernel change or new updates without re-provisioning.
- Given a second `provision.yml` run, when it finishes, then the motd role reports no change.
- Given `task lint`, when it runs, then all linters pass.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- medium (patch): `20-updates` printed `0 updates can be applied immediately.` when nothing is pending, and dropped the count for exactly one update (`1 update ...`) (edge-case, blind, verification-gap). Verified in the droplet's `apt_check.py`: the count line is always written, singular via `dngettext`, the hint only when something is pending. Fixed: match `can be applied immediately`, print nothing when the count is 0; re-run against the real stamp prints the two lines and a blank line.
- medium (patch): `50-landscape-sysinfo` handled with `dpkg-divert` (found by me, also edge-case). The link is not owned by a package; `landscape-common`'s postinst recreates it with `ln -sf` on every upgrade and ignores diversions, and a re-run would hit the existing diversion. Fixed: debconf `landscape-common/sysinfo` = `Do not display sysinfo on login` (question exists on the droplet) and remove the link.
- low (patch): comment and docs claimed removing the exec bit survives package upgrades (blind, edge-case). dpkg judges conffiles by content, so a changed or new script comes back until the next provision run. Wording corrected in the role and `provisioning.md`.
- low (patch): the role's own script list was written twice (blind). Now `motd_scripts` in defaults.
- low (patch): `.folderslintrc` had motd-specific entries (blind). Replaced with the generic `configs-cloud/*/ansible/roles/*/files`.
- medium (defer): no automated check runs the MOTD scripts against stamp fixtures or asserts the exec bits and idempotence (verification-gap, blind). Cloud roles have no Molecule/InSpec harness yet; same gap as Story 3.2.
- low (rejected): security-update line dropped (blind). The frozen intent fixes the update info to the two lines.
- low (rejected): new scripts added by later packages show up until the next provision run (blind). Documented with the upgrade wording; re-provision fixes it.
- low (rejected): English-only grep, `motd_share_dir` hardcoded in `00-banner`, no `/etc/os-release` fallback, no OS guard, no rollback docs, warnings like `98-fsck-at-reboot` disabled, no hostname in the banner, `run-parts` vs `/run/motd.dynamic` in the docs (blind, edge-case). Ubuntu-only droplet with C locale; the layout and kept notices are fixed by the intent; cosmetic otherwise.

## Design Notes

Why scripts and not `/etc/motd`: `pam_motd` prints `/run/motd.dynamic` (built from `/etc/update-motd.d` at login) and then `/etc/motd`; `sshd` does not print the MOTD itself (`PrintMotd no`).

## Verification

**Commands:**
- `ansible-playbook --syntax-check -i configs-cloud/digital-ocean/ansible/inventory configs-cloud/digital-ocean/ansible/playbooks/provision.yml` -- expected: success (needs the vault password or the vault line stripped).
- `task lint` -- expected: all pass.
- After the user provisions: `ssh root@<droplet-ip> 'run-parts --lsbsysinit /etc/update-motd.d | cat -A'` -- expected: exactly the layout above (agent SSH works read-only).

**Manual checks (if no CLI):**
- User logs in over SSH and compares with the layout; runs `task cloud:digital-ocean:ansible:provision` twice: the motd role reports no change the second time.
