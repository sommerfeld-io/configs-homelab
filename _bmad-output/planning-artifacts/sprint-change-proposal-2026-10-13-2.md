# Sprint Change Proposal: Dedicated `fantasy-hockey` User for the App Deployment

- **Date:** 2026-10-13
- **Trigger:** new requirement from the user, raised after Story 3.1 and before Epic 4 started
- **Mode:** Batch
- **Scope classification:** Minor
- **Status:** approved by the user and applied on 2026-10-13

## 1. Issue Summary

The user wants the fantasy hockey app on the droplet to run under its own Linux user, not under `root`. Category: **new requirement from a stakeholder**. No existing requirement is invalidated.

Requirements as stated:

1. Ansible provisions a user `fantasy-hockey` when it rolls out the app.
2. The user gets a bash config from Ansible.
3. The user is a member of the `docker` group.
4. The app runs as this user, not as root.
5. This is **not** part of `provision.yml`. It belongs to the playbook dedicated to deploying the app.
6. That playbook is named `deploy-fantasy-hockey.yml` (instead of the planned `deploy-services.yml`) and targets the `fantasy-hockey` hosts group.

## 2. Impact Analysis

### Checklist

- 1.1 Triggering story: [N/A] no story triggered it; a stakeholder request
- 1.2 Core problem: [x] new requirement, least-privilege execution of the app
- 1.3 Evidence: [x] the user's request, including the explicit boundary to `provision.yml`
- 2.1 Current epic: [x] Epic 4 is in backlog and has not started, so Story 4.1 can absorb the change
- 2.2 Epic-level changes: [x] none to the epic goal; Story 4.1 gains acceptance criteria
- 2.3 Remaining epics: [x] Story 4.3 (replacement drill) re-runs deploy, so the user comes back with it; Epic 6 runs the same playbook from CI as root over SSH and needs no change
- 2.4 Obsolete or new epics: [N/A] none
- 2.5 Epic order: [N/A] unchanged
- 3.1 PRD: [N/A] the PRD does not cover the droplet
- 3.2 Architecture: [N/A] no new decision; user and bash config are node configuration declared in Ansible (AD-1), the role lives under `configs-cloud/digital-ocean/ansible/roles` (AD-4 carve-out, AD-10)
- 3.3 UI/UX: [N/A] no UX artifacts
- 3.4 Other artifacts: [!] `SPEC.md` (CAP-3), `platform-decisions.md`, specs `epics.md`, `stories.yaml` and the docs under `docs/cloud/digital-ocean` need the same fact (the project pitfall: update every planning doc in the same change)
- 4.1 Direct adjustment: viable; effort low, risk low
- 4.2 Rollback: not viable, nothing to roll back
- 4.3 MVP review: not needed

### Why Story 4.1

Story 4.1 moves the fantasy-hockey role and adds `deploy-fantasy-hockey.yml`, the playbook that rolls out the app. The user and the way the app runs are part of that rollout. Stories 4.2 (Dependabot) and 4.3 (replacement drill) do not create or run the app. Epic 3 stories target `provision.yml`, which the user excluded.

### Story Impact

Only Story 4.1. It grows in size; if it becomes too large when planned, `bmad-build` offers the split.

### Technical Impact

- `deploy-fantasy-hockey.yml` (group `fantasy-hockey`) creates the user and applies the bash config before it runs the app.
- Existing roles can be reused through relative paths: the `docker` role's `50-user.yml` creates a user and adds it to the `docker` group; the `bash` role's `10-bash-config.yml` writes `/home/<user>/.bashrc` with `ps1`. Both read the variable `default_user`, so the deploy play sets `default_user: fantasy-hockey` and defines a non-root `ps1`.
- The moved fantasy-hockey role currently uses `default_user` for file ownership and runs compose as that user on the Pi. On the droplet `default_user` must be `fantasy-hockey` for the deploy play, while `provision.yml` keeps `default_user: root`.
- The app's data directory owner (container uid 1000) and the data file rule (seeded only when absent) stay as they are.
- Decided when planning Story 4.1, not here: the prompt value for `ps1`, and whether the user needs an SSH key (not requested).

## 3. Recommended Approach

**Direct adjustment**: add acceptance criteria to Story 4.1 and carry the fact into the other planning docs. Effort low, risk low, no timeline impact.

## 4. Detailed Change Proposals

### Change 1: `epics-fantasy-hockey-digitalocean.md`, Story 4.1

Insert after the first acceptance criteria block (the one ending with "serves the app from outside the home network"):

````markdown
**Given** `deploy-fantasy-hockey.yml` runs against the droplet and `provision.yml` is unchanged
**When** the deploy finishes
**Then** a user `fantasy-hockey` exists and is a member of the `docker` group
**And** the user has a bash config from Ansible
**And** `provision.yml` does not create the user

**Given** the app is deployed
**When** I inspect how it runs
**Then** docker compose is run by the user `fantasy-hockey`, not by `root`
**And** a second deploy run changes nothing
````

Rationale: the user, its group, the bash config and the "not root" rule come directly from the request; the boundary to `provision.yml` is explicit.

### Change 2: `specs/spec-fantasy-hockey-digitalocean/epics.md`, E3 bullet

Add after the "nginx on port 80 ..." bullet:

```markdown
- `deploy-fantasy-hockey.yml` provisions a user `fantasy-hockey` (bash config from Ansible, member of the `docker` group) and runs the app with that user, not with root. This is not part of `provision.yml`.
```

### Change 3: `specs/spec-fantasy-hockey-digitalocean/stories.yaml`, entry `id: "9"`

Append to `description`:

```text
deploy-fantasy-hockey.yml also creates the user fantasy-hockey (bash config from Ansible, member of the docker group) and runs the app with it, not with root; provision.yml does not create this user.
```

Append to `invoke_dev_with`:

```text
The deploy play sets default_user to fantasy-hockey (provision.yml keeps root) so the reused docker and bash roles work on the new user; define a non-root ps1. Run docker compose as that user and keep the data file rule unchanged.
```

### Change 4: `specs/spec-fantasy-hockey-digitalocean/SPEC.md`, CAP-3 success

Append to the CAP-3 `success` line: "; the app runs as the dedicated user `fantasy-hockey` (bash config from Ansible, member of the `docker` group), not as root".

### Change 5: `specs/spec-fantasy-hockey-digitalocean/platform-decisions.md`

Add under "Inventory and playbooks":

```markdown
- `deploy-fantasy-hockey.yml` creates the user `fantasy-hockey` (bash config from Ansible, member of the `docker` group) and runs the app as that user, not as root. `provision.yml` stays root-only and does not create it.
```

### Change 6: rename `deploy-services.yml` to `deploy-fantasy-hockey.yml`

Replace the name wherever it is planned, and keep "targets the `fantasy-hockey` group":

- `epics-fantasy-hockey-digitalocean.md`: Story 4.1 title becomes `Story 4.1: Move fantasy-hockey role and deploy-fantasy-hockey.yml with nginx`.
- `specs/spec-fantasy-hockey-digitalocean/stories.yaml`: entry `id: "9"` title and description.
- `specs/spec-fantasy-hockey-digitalocean/epics.md`: E3 bullet.
- `specs/spec-fantasy-hockey-digitalocean/platform-decisions.md`: "`provision.yml` targets `ubuntu`; `deploy-fantasy-hockey.yml` targets `fantasy-hockey`."
- `architecture/.../ARCHITECTURE-SPINE.md`: the layout comment listing `deploy-services.yml`.
- `implementation-artifacts/epic-3-context.md`: the cross-reference to the Epic 4 playbook.
- `implementation-artifacts/sprint-status.yaml`: the story key follows the title, so `4-1-move-fantasy-hockey-role-and-deploy-services-yml-with-nginx` becomes `4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx` (still `backlog`, so nothing else references it).
- Left unchanged on purpose: the finished `spec-3-1` file, the brainstorming folder, the `.memlog.md` files and the architecture review notes. They record history.

Rationale: a name that says what the playbook deploys; the group target stays `fantasy-hockey`, as before.

### Change 7: docs under `docs/cloud/digital-ocean`

No edit now. Story 4.1 documents the user in the deploy page, as every story does.

## 5. Implementation Handoff

- **Scope:** Minor. The Developer agent applies Changes 1 to 6 as a planning-doc edit; no code changes now.
- **Next:** `bmad-build 4.1` picks the new criteria up when Epic 4 starts (after Epic 3).
- **Success criteria:** the five planning docs state the same user, group, bash and "not root" facts; `provision.yml` is unchanged.
