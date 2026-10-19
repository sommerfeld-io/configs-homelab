# Sprint Change Proposal: Add Story 3.4, the Droplet MOTD

- **Date:** 2026-10-13
- **Trigger:** new requirement from the user, raised before Epic 3 started
- **Mode:** Batch
- **Scope classification:** Minor
- **Status:** approved by the user and applied on 2026-10-13

## 1. Issue Summary

The user wants the droplet's login banner (MOTD) to be set by provisioning. Category: **new requirement from a stakeholder**. No existing requirement or decision is invalidated.

The wanted login output, top to bottom:

1. a blank line
2. a small ASCII art "DigitalOcean"
3. a blank line
4. an OS line like Ubuntu's `Welcome to Ubuntu 26.04.1 LTS (GNU/Linux 7.0.0-31-generic x86_64)`, **derived from the running system, not static text**
5. a blank line
6. the update info exactly as Ubuntu prints it today, **reflecting the real state, not static text**: `12 updates can be applied immediately.` and `To see these additional updates run: apt list --upgradable`
7. a blank line

The default "System restart required" notice may also be shown. All other default MOTD sections (help and documentation links, system information, ESM notices and so on) are suppressed. The user's first message said "black line"; they confirmed it is a typo for "blank line".

Evidence: the user quoted today's Ubuntu MOTD on the droplet as the reference.

## 2. Impact Analysis

### Checklist

- 1.1 Triggering story: [N/A] no story triggered it; a stakeholder request
- 1.2 Core problem: [x] new requirement, a login banner that shows the host identity and live OS and update state
- 1.3 Evidence: [x] the user's MOTD sample and layout
- 2.1 Current epic: [x] Epic 3 is in backlog with no story started, so it can absorb the story as its last one
- 2.2 Epic-level changes: [x] add Story 3.4 and extend the epic goal sentence by "and a login banner"; FR coverage (FR2, FR4) is unchanged
- 2.3 Remaining epics: [N/A] Epics 4 to 6 are unaffected; the replacement drill in Epic 4 re-runs `provision.yml`, so the banner comes back with it
- 2.4 Obsolete or new epics: [N/A] none
- 2.5 Epic order: [N/A] unchanged; the story is last and depends only on Story 3.1
- 3.1 PRD: [N/A] the PRD does not cover the droplet's login experience
- 3.2 Architecture: [N/A] no new decision; the banner is node configuration declared in Ansible (AD-1) and the role lives under `configs-cloud/digital-ocean/ansible/roles` (AD-4 carve-out, AD-10)
- 3.3 UI/UX: [N/A] no UX artifacts
- 3.4 Other artifacts: [!] docs under `docs/cloud/digital-ocean` need a section (CAP-7, every story updates the docs in the same change); `AGENTS.md` has no conflicting policy
- 4.1 Direct adjustment: viable; effort low, risk low
- 4.2 Rollback: not viable, nothing to roll back
- 4.3 MVP review: not needed, no scope reduction

### Epic Impact

Epic 3 grows from three to four stories. Its goal changes from "provisioned from a tag-based inventory with Docker, swap and Alloy" to include "and a login banner".

### Story Impact

New Story 3.4 after Story 3.3. It extends the `provision.yml` that Story 3.1 creates, so it cannot start before 3.1 is done. It is independent of Stories 3.2 and 3.3.

### Technical Impact

- A cloud-specific role under `configs-cloud/digital-ocean/ansible/roles`, applied by `provision.yml` to the `ubuntu` group.
- Scripts in `/etc/update-motd.d/`: a static banner script and dynamic scripts for the OS line and the update info, plus disabling the default Ubuntu scripts that print the other sections.
- Verification is an SSH login. The open Epic 2 retro question, how Epic 3 automation reaches the droplet over SSH (the agent's own SSH was blocked), applies here: either an allow-rule for SSH to the reserved IP or a user-run check. It must be decided before this story is verified.

## 3. Recommended Approach

**Direct adjustment**: add Story 3.4 to the existing plan. Effort low, risk low, no timeline impact on Stories 3.1 to 3.3.

## 4. Detailed Change Proposals

### Change 1: `epics-fantasy-hockey-digitalocean.md`, epic list and Epic 3 goal

OLD (both places the goal appears, under "Epic List" and under "Epic 3"):

```text
The droplet is provisioned from a tag-based inventory with Docker, swap and Alloy.
```

NEW:

```text
The droplet is provisioned from a tag-based inventory with Docker, swap, Alloy and a login banner.
```

Rationale: the epic goal must name the new capability.

### Change 2: `epics-fantasy-hockey-digitalocean.md`, new Story 3.4 after Story 3.3

NEW:

````markdown
### Story 3.4: Droplet login banner (MOTD) with live OS and update info

As an operator,
I want a clean login banner on the droplet,
So that I see at a glance which host and OS I am on and whether updates are pending.

**Acceptance Criteria:**

**Given** `provision.yml` has run on the droplet
**When** I log in via SSH
**Then** the MOTD is exactly: a blank line, the ASCII art below, a blank line, the OS line, a blank line, the update info, a blank line
**And** none of the other default MOTD sections appear (help and documentation links, system information, ESM notices and so on), except the default `*** System restart required ***` notice, which is shown after the update info when a reboot is pending

```text
 ___  _      _ _        _  ___
|   \(_)__ _(_) |_ __ _| |/ _ \ __ ___ __ _ _ _
| |) | / _` | |  _/ _` | | (_) / _/ -_) _` | ' \
|___/|_\__, |_|\__\__,_|_|\___/\__\___\__,_|_||_|
       |___/
```

**Given** the OS line and the update info
**When** I log in
**Then** the OS line has the form `Welcome to <PRETTY_NAME> (GNU/Linux <kernel release> <architecture>)`, for example `Welcome to Ubuntu 26.04.1 LTS (GNU/Linux 7.0.0-31-generic x86_64)`
**And** the update info has the form `<N> updates can be applied immediately.` followed by `To see these additional updates run: apt list --upgradable`
**And** both are computed from the running system at login, not written as static text, so a later kernel change or new package updates show up without re-provisioning

**Given** a second `provision.yml` run
**When** it finishes
**Then** nothing changes
**And** the docs describe the MOTD and how it is built
````

Rationale: the layout, dynamic requirement, suppression and idempotence come directly from the user's request. The art is the figlet `small` rendering of `DigitalOcean`, pinned here so the check is exact.

### Change 3: `specs/spec-fantasy-hockey-digitalocean/epics.md`, E2 bullet

Add under "E2 Provisioning via Ansible", after the "ansible-lint covers the new folder." bullet:

```markdown
- Login banner (MOTD): blank line, ASCII art "DigitalOcean", blank line, a live OS line, blank line, the live update info, blank line; all other default MOTD sections suppressed.
```

### Change 4: `specs/spec-fantasy-hockey-digitalocean/stories.yaml`, new entry `8a`

Insert after the entry with `id: "8"`:

```yaml
- id: "8a"
  title: Droplet login banner (MOTD) with live OS and update info
  description: >-
    Extend provision.yml with a cloud role that sets the droplet MOTD to: a blank line, the pinned figlet "small" ASCII art "DigitalOcean", a blank line, an OS line "Welcome to <PRETTY_NAME> (GNU/Linux <kernel> <arch>)", a blank line, Ubuntu's update info ("<N> updates can be applied immediately." and "To see these additional updates run: apt list --upgradable"), and a blank line (CAP-2).
    The OS line and update info are computed at login, never static; every other default MOTD section is suppressed, except Ubuntu's own reboot-required notice, which stays.
    Docs updated in the same change.
  invoke_dev_with: >-
    Use scripts in /etc/update-motd.d/ and disable the default scripts that print other sections instead of replacing /etc/motd.
    Run first on the droplet, before writing the role: list /etc/update-motd.d/ on Ubuntu 26.04 to see which default scripts exist, and run the update-notifier apt_check helper with --human-readable to confirm it prints exactly the two update lines.
    Check what the MOTD shows with zero pending updates and with a pending reboot, and keep the layout intact in both cases.
    Decide with the user how SSH verification is done (allow-rule for SSH to the reserved IP, or a user-run check) before verifying.
```

Rationale: id `8a` keeps the later spec ids stable (user decision). The checks are in `invoke_dev_with` because the Epic 2 retro lessons say to run documented commands first and copy constraints into the story.

### Change 5: `sprint-status.yaml`

OLD:

```yaml
  3-3-environment-homelab-label-in-the-homelab-alloy-config: backlog
  epic-3-retrospective: optional
```

NEW:

```yaml
  3-3-environment-homelab-label-in-the-homelab-alloy-config: backlog
  3-4-droplet-motd-with-banner-live-os-line-and-update-info: backlog
  epic-3-retrospective: optional
```

Also set `last_updated` to the apply time.

## 5. Assumptions to confirm

These are not in the user's description, so I made a call. Say if any is wrong.

- **Zero pending updates:** Ubuntu prints the update info only when updates exist. I assume that with none pending, the update lines and their trailing blank line are omitted, and the rest of the layout stays intact.
- **Reboot-required notice (decided by the user):** the default `*** System restart required ***` notice may be shown. I place it after the update info, before the closing blank line, and keep the 98-reboot-required script enabled.
- **"Last login" line:** it comes from sshd, not the MOTD, so it is out of scope and stays.
- **Update count freshness:** Ubuntu's update count is cached and refreshed by apt hooks. "Live" here means the state Ubuntu last computed, as in today's MOTD.

## 6. Implementation Handoff

- **Scope:** Minor. Direct implementation by the developer agent after approval.
- **Applying these changes:** the five edits above, then done.
- **Story work:** later, with `bmad-build` for Story 3.4, after Story 3.1 is done.
- **Success criteria:** the five planning edits match this proposal; the Story 3.4 acceptance criteria are in `epics-fantasy-hockey-digitalocean.md`; `sprint-status.yaml` lists `3-4-…` as backlog with `epic-3-retrospective` last.
- **Open dependency:** the SSH verification decision (Epic 2 retro, open question 1).
