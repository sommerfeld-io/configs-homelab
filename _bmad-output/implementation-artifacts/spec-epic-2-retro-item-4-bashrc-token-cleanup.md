---
title: 'Clean up the .bashrc token exports in bash-secrets.yml'
type: 'bugfix'
created: '2026-10-12'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `configs-homelab/ansible/tasks/bash-secrets.yml` leaves the stale `export DIGITALOCEAN_TOKEN=<old token>` in every existing `.bashrc`, and its `lineinfile` has no `regexp`, so a rotated secret appends a second export instead of replacing the first (Epic 2 retro action item 4).

**Approach:** Add `DIGITALOCEAN_TOKEN` to the obsolete-secrets loop, and give the write task a `regexp` derived from the variable name in `line`, so an existing export is replaced in place.

</frozen-after-approval>

## Implementation Notes

- Changed `configs-homelab/ansible/tasks/bash-secrets.yml` only: `regexp` on the write task (`^export NAME=`, derived from `line`) and `DIGITALOCEAN_TOKEN` in the obsolete list.
- Verified on a scratch `.bashrc` with Ansible: stale `DIGITALOCEAN_TOKEN` removed, rotated `DIGITALOCEAN_ACCESS_TOKEN` replaced in place (value containing `=` ok), second run `changed=0`. `task lint` exit 0.
- Only `desktop.yml` calls the task and it exports `DIGITALOCEAN_ACCESS_TOKEN`, so no write/remove flapping.

## Review Triage Log

- Rigid `^export NAME=` match: low, rejected. Every line is written by this playbook in that exact form.
- Secret in logs / no `no_log`: medium, deferred. Pre-existing (the include_tasks loop already carries the token in `item`), not caused by this change.
- `line` without `=` not guarded: low, rejected. Callers are hardcoded `export NAME=value` literals.
- Write/remove flapping on `DIGITALOCEAN_TOKEN`: false. The only caller (`desktop.yml:24-25`) exports `DIGITALOCEAN_ACCESS_TOKEN`; the regexps differ.
- No Molecule/InSpec coverage of replace and removal: medium, deferred.
- Scope gaps (root write, other profile files, history, running shells): low, rejected. Out of the retro item.
