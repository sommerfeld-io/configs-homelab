---
title: 'Wait for new droplets in deploy, fix the Epic 3 docs drift, quiet the flaky link check'
type: 'chore'
created: '2026-10-13'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Three open Epic 3 retro action items, built together at the user's request:

- Item 11 (findings 6 and 7): `task cloud:digital-ocean:deploy` runs provision right after `opentofu:apply`, with no wait for SSH or cloud-init. A droplet without a public IPv4 silently gets no `ansible_host`. Story 4.3 (replacement drill) is the first time `deploy` creates a droplet.
- Item 9 (finding 4): `tasks-and-linters.md`, `droplet.md` and `provisioning.md` no longer match the as-built.
- Item 16 (finding 17): the markdown link check fails commits on transient 502/503 errors and on 429.

**Approach:**

- `provision.yml` gets a first play without fact gathering. It fails clearly when `ansible_host` is missing, waits for the connection, then waits for cloud-init.
- The listed docs drift is fixed, and the new wait play is documented.
- `.lychee.toml` gets more and longer retries and accepts the transient gateway codes 502 to 504 next to 429.

</frozen-after-approval>

## Implementation Notes

- Item 11: `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` has a new first play `Wait for new droplets` (`gather_facts: false`): an assert on the inventory's `ansible_host`, `wait_for_connection` (300 s), then `cloud-init status --wait` (rc 0 and 2 accepted, 1 fails). The fix lives in the playbook, so `ansible:provision` on its own gets it too, not only `deploy`.
- Surprise: inside a task, `ansible_host is defined` is always true, because Ansible falls back to the inventory host name. The first version therefore did not catch a missing IP (it hung in `wait_for_connection`). The assert now reads `hostvars[inventory_hostname].ansible_host`.
- Checked: the wait play against the live droplet (3 ok, 0 changed). With `-e ansible_host=` it fails with the message. With a static scratch inventory without `ansible_host` it fails at the assert. On the droplet, cloud-init is 26.1 and `status --wait` returns 0. `--syntax-check` of the whole playbook still needs the vault password (pre-existing, same reason as the ansible-lint exclusion).
- After review, the cloud-init wait is capped with `timeout 600` (rc 124 fails), and the docs name the 10-minute limit, the apt-lock gap and that a failing droplet only drops itself.
- Not changed: the inventory `compose` and `strict: false` stay. The assert is the safety net. The apt lock after cloud-init (apt-daily or unattended-upgrades on first boot) is not waited for; the apt module's default `lock_timeout` of 60 s covers short overlaps.
- Item 9: `tasks-and-linters.md` (tree with cloud roles, provision row with MOTD and the wait, folderslint row with `roles` and the role subfolders, ansible-lint row naming the `provision.yml` exclusion and why), `droplet.md` (Tags row), `provisioning.md` (the two plays, role order `bash` before `docker`, stray blank line removed, fleet and cloud roles told apart).
- Item 16: `.lychee.toml` gets `max_retries = 4` and `retry_wait_time = 3` (exponential backoff, about 45 s per failing link). 429 stays accepted. 5xx is retried, not accepted, after review. `task lint` exit 0.
- The deferred-work entries for items 9 and 16 are left as they are (append-only).


## Review Triage Log

- Lychee comment claims accepted codes are retried: medium, patched. Accepted statuses count as success at once; the config now retries 5xx instead of accepting it.
- Accepting 502–504 for every host hides dead links: medium, patched. Same root cause; `502..=504` removed from `accept`.
- Retries slow the hook a lot (5 x 5 s backoff): low, patched. Now 4 retries from 3 s, about 45 s, stated in the comment.
- Lychee image unpinned while relying on the range syntax: false after the patch. The config no longer uses ranges, and the `latest` tag predates this change.
- `cloud-init status --wait` can hang forever: medium, patched. `timeout 600` added; rc 124 fails the host. Re-run live: ok=3, changed=0.
- No apt-lock wait: maybe-false (medium if true), deferred. The docker role sets no `lock_timeout`, so the apt default of 60 s applies; whether first-boot apt-daily holds the lock longer shows up in the Story 4.3 drill. The docs now state the gap.
- Host-key mismatch on a reused IP not covered: false. `provisioning.md` already has "Replaced Droplet and Host Key" with `ssh-keygen -R`.
- Wait play has no automated check: medium, deferred. A vault-free import would make it lintable; belongs to the cloud test-harness story (item 15).
- Tracking not updated, item numbering mixed: partly real, patched. Spec and sprint-status items 9, 11 and 16 are now `done` (`sprint_status.py` stamped the time). The numbering is the sprint-status action-item ids, which is what the user named.
- Docs gaps (link-check behaviour, cloud-init limit, partial failure): low, patched for provisioning.md. The link-check behaviour is explained in the `.lychee.toml` comment; there is no lint page for lychee to extend.
