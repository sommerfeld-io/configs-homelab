---
title: 'Pin every collection the droplet provisioning uses'
type: 'chore'
created: '2026-10-13'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `configs-cloud/digital-ocean/ansible/requirements.yml` pins only `community.digitalocean`. Provisioning also runs `community.general.capabilities` (and, on Arch, `community.general.pacman`) from the fleet Alloy and Docker roles, and that collection comes from whatever the devcontainer has installed. This only partly meets AD-7 / AD-10 "Pinning" (Epic 3 retro action item 10).

**Approach:** Add `community.general` to `requirements.yml`, pinned to the version provisioning was verified with, and say in the provisioning docs that both collections are pinned.

</frozen-after-approval>

## Implementation Notes

- Added `community.general` 13.5.0 to `configs-cloud/digital-ocean/ansible/requirements.yml` and named both collections in `docs/cloud/digital-ocean/provisioning.md`.
- 13.5.0 is the devcontainer's installed version, the one Epic 3 provisioned the droplet with; it is the only copy on `COLLECTIONS_PATHS`, so `ansible-galaxy collection install -r` is a no-op today.
- Grep of every role `provision.yml` runs: the only non-builtin modules are `community.general.capabilities` (Alloy, runs) and `community.general.pacman` (Arch branches, never reached on `hosts: ubuntu`). `community.crypto` is only in `bash/tasks/20-ssh-keypair.yml`, which provisioning does not include.
- `task lint` exit 0. Provision not re-run (needs the vault password); the pin changes nothing installed.

## Review Triage Log

- Docs/comment say the Docker role uses community.general: low, patched. Only `pacman` on the Arch path; wording now names Alloy's `capabilities` only.
- No updater for Galaxy pins: medium, deferred. Real, pre-existing for `community.digitalocean`; needs a Renovate-or-manual decision.
- No check that `requirements.yml` is complete: medium, deferred. Belongs to the cloud test-harness story (retro item 15).
- Implementation Notes empty / status in-progress: false. Notes and status are written at finalize, which the reviewer ran before.
- Minimum ansible-core not stated: low, rejected. The devcontainer image is pinned and provisioning already ran with this exact collection version.
- Installed copy may not be the one Ansible loads: false. `ansible-config dump` shows `~/.ansible/collections` first, and it holds the only `community.general` (13.5.0).
- New deferred-work entries lack context: low, patched. They now cite the retro findings and note the provisioning.md sentence already fixed here.
