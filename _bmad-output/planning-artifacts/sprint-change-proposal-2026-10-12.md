# Sprint Change Proposal: Reconcile Planning Docs with the As-Built Droplet

- **Date:** 2026-10-12
- **Trigger:** Epic 2 retrospective, action item `epic-2-retro-item-3` ([epic-2-retro-2026-10-12.md](../implementation-artifacts/epic-2-retro-2026-10-12.md), Finding 1)
- **Mode:** Batch
- **Scope classification:** Minor
- **Status:** approved by the user and implemented on 2026-10-12

## 1. Issue Summary

Epic 2 built the droplet, reserved IP and volume, but three facts turned out differently from what the planning docs say, and only the epics file and `epic-2-context.md` were partly reconciled (commit `c993be3`):

1. **Token variable.** `doctl`, OpenTofu and the devcontainer read `DIGITALOCEAN_ACCESS_TOKEN`; the vault key stays `DIGITALOCEAN_TOKEN` (since `a12d7ff` / `6f8671f`). `SPEC.md`, `platform-decisions.md`, `stories.yaml`, the spec `epics.md` and the architecture still call `DIGITALOCEAN_TOKEN` "the token env var". Worst case: `platform-decisions.md:36` tells Story 3.1 to feed the dynamic inventory from an env lookup of `DIGITALOCEAN_TOKEN`, a variable that no longer exists in the shell.
2. **SSH keys.** The planning docs ask for "both existing SSH keys" (the local `id_rsa.pub` key and `picon___id_rsa.pub`). They are the same key (matching fingerprint), so Story 2.4 injects only `picon___id_rsa.pub`; the second key in the plan is the CI keypair of the GitHub Actions epic (user decision, `spec-2-4`).
3. **Mount path.** DigitalOcean turns the hyphens of the volume name into underscores: the volume `prod-fantasy-hockey-data` is mounted at `/mnt/prod_fantasy_hockey_data` (user SSH check, `spec-2-5`). The planning docs say `/mnt/<volume-name>`, and Epic 4 inherits the wrong data path.

Smaller drift: the droplet name is exactly `prod-fantasy-hockey` (built as `<stage>-<key>`), not "starting with"; the token scope names in the planning docs (`volume`, `reserved IP`) differ from the documented scopes (`block_storage`, `reserved_ip`, plus `actions`).

**Category:** misunderstanding of original requirements / facts discovered during implementation. No requirement changes; the docs catch up with reality.

## 2. Impact Analysis

### Checklist

| Item                                   | Status | Note                                                                                                     |
|----------------------------------------|--------|----------------------------------------------------------------------------------------------------------|
| 1.1 Triggering story                   | [x]    | Stories 2.1–2.5, surfaced by the Epic 2 retro                                                            |
| 1.2 Core problem                       | [x]    | Planning docs describe planned, not built facts                                                          |
| 1.3 Evidence                           | [x]    | Retro Finding 1 with file:line references; live `doctl`, SSH and `plan` checks                           |
| 2.1 Current epic                       | [N/A]  | Epic 2 is done; nothing to rework                                                                        |
| 2.2 Epic-level changes                 | [x]    | Wording of done Stories 2.4 and 2.5 ACs aligned to the decisions; no scope change                        |
| 2.3 Remaining epics                    | [!]    | Epic 3 (inventory token) and Epic 4 (data path) read the corrected facts                                 |
| 2.4 Obsolete or new epics              | [N/A]  | None                                                                                                     |
| 2.5 Epic order                         | [N/A]  | Unchanged                                                                                                |
| 3.1 PRD                                | [N/A]  | No conflict; the PRD does not name the token, keys or mount path                                         |
| 3.2 Architecture                       | [!]    | `ARCHITECTURE-SPINE.md:138` (inventory token)                                                            |
| 3.3 UI/UX                              | [N/A]  | No UX artifacts                                                                                          |
| 3.4 Other artifacts                    | [x]    | Docs, code and CI already match reality; `epic-2-context.md` is a compiled cache, updated for consistency |
| 4.1 Direct adjustment                  | Viable | Low effort, low risk                                                                                     |
| 4.2 Rollback                           | Not viable | Nothing to roll back; the built state is correct                                                     |
| 4.3 MVP review                         | Not viable | MVP unaffected                                                                                       |
| 4.4 Path                               | [x]    | Option 1, direct adjustment                                                                              |
| 6.4 sprint-status.yaml                 | [N/A]  | No epics or stories added, removed or renumbered; only `epic-2-retro-item-3` moves to `done` after implementation |

### Epic and Story Impact

- **Epic 2 (done):** AC wording of Stories 2.4 and 2.5 changes to what was decided and built. Story titles keep `DIGITALOCEAN_TOKEN` (it is the vault key name and matches the sprint-status keys).
- **Epic 3:** Story 3.1 reads the inventory token from `DIGITALOCEAN_ACCESS_TOKEN`. Editing the planning docs makes the cached `epic-2-context.md` older than the planning artifacts; the next `bmad-build` compiles a fresh `epic-3-context.md` anyway.
- **Epic 4:** Story 4.1 data path becomes `/mnt/prod_fantasy_hockey_data/fantasy-hockey`.
- **Epics 5, 6:** no change (Story 6.3 keeps the CI keypair and the org-level token secret).

### Technical Impact

None. Code, OpenTofu, docs and CI already reflect the built state; only planning artifacts change.

## 3. Recommended Approach

**Direct adjustment (Option 1):** edit the planning artifacts below to match the built state. Effort low, risk low, no timeline impact. Rollback and MVP review do not apply, because the as-built state is the intended one and was confirmed by the user's decisions during Epic 2.

## 4. Detailed Change Proposals

### 4.1 `specs/spec-fantasy-hockey-digitalocean/SPEC.md`

**Line 19 (CAP-1 success)**

OLD:

```text
From a clean checkout with `DIGITALOCEAN_TOKEN` set, the `cloud:digital-ocean` OpenTofu task creates one droplet `prod-fantasy-hockey…` (tag `prod`, project `sommerfeld.io`, ext4 volume mounted under `/mnt/<volume-name>`); ...
```

NEW:

```text
From a clean checkout with `DIGITALOCEAN_ACCESS_TOKEN` set, the `cloud:digital-ocean` OpenTofu task creates one droplet `prod-fantasy-hockey` (tag `prod`, project `sommerfeld.io`, ext4 volume mounted under `/mnt/<volume_name>`, e.g. `/mnt/prod_fantasy_hockey_data`); ...
```

Rationale: real variable, exact name, real mount path form.

**Line 65 (constraints)**

OLD:

```text
- `DIGITALOCEAN_TOKEN` is the token env var. Locally it comes from `configs-homelab/ansible/vars/vault.yml` via `configs-homelab/ansible/tasks/bash-secrets.yml`, ...
```

NEW:

```text
- `DIGITALOCEAN_ACCESS_TOKEN` is the token env var that `doctl`, OpenTofu and the dynamic inventory read. Locally it is exported from the vault key `DIGITALOCEAN_TOKEN` in `configs-homelab/ansible/vars/vault.yml` via `configs-homelab/ansible/tasks/bash-secrets.yml`, ...
```

Rationale: distinguishes the env var from the vault key.

**Line 92 (assumptions)**

OLD:

```text
- `picon___id_rsa.pub` is the name of an SSH key already registered on DigitalOcean, alongside the key from the local `id_rsa.pub`.
```

NEW:

```text
- `picon___id_rsa.pub` is the SSH key already registered on DigitalOcean; it is the same key as the operator workstation's local `id_rsa.pub`. The CI keypair is added with E5.
```

Rationale: there is only one existing key.

### 4.2 `specs/spec-fantasy-hockey-digitalocean/platform-decisions.md`

**Droplet table, lines 11, 15, 16, 18**

OLD:

```text
| Name and tag    | Name starts with `prod-fantasy-hockey`; tag `prod`                                        |
| Volume          | 2 GB, ext4, `initial_filesystem_type`, attached at creation; mount `/mnt/<volume-name>`   |
| Data path       | `/mnt/<volume-name>/fantasy-hockey` (or whatever works best)                              |
| SSH keys        | Existing DO key from local `id_rsa.pub` plus the key named `picon___id_rsa.pub`           |
```

NEW:

```text
| Name and tag    | Name `prod-fantasy-hockey` (`<stage>-<key>`); tag `prod`                                                             |
| Volume          | 2 GB, ext4, `initial_filesystem_type`, attached at creation; mounted at `/mnt/prod_fantasy_hockey_data` (hyphens become underscores) |
| Data path       | `/mnt/prod_fantasy_hockey_data/fantasy-hockey`                                                                      |
| SSH keys        | `picon___id_rsa.pub` (the same key as the local `id_rsa.pub`); the CI key is added in E5                             |
```

(The table is re-padded so every row of the column has the same width.)

**Secrets table, line 25**

OLD:

```text
| `DIGITALOCEAN_TOKEN`  | `vault.yml` through `bash-secrets.yml`     | Org-level GitHub secret       |
```

NEW:

```text
| DigitalOcean token    | vault key `DIGITALOCEAN_TOKEN` in `vault.yml`, exported as `DIGITALOCEAN_ACCESS_TOKEN` through `bash-secrets.yml` | Org-level GitHub secret |
```

(Re-padded.)

**Line 30 (token scopes)**

OLD:

```text
- Token scopes: droplet, ssh_key, volume, reserved IP, project; firewall or domain only if needed.
```

NEW:

```text
- Token scopes: droplet, ssh_key, block_storage, reserved_ip, project, actions (as documented in `docs/cloud/digital-ocean/api-token.md`); firewall or domain only if needed.
```

Rationale: same names as the documented scopes. Whether a tag scope is needed is open in `epic-2-retro-item-6`.

**Line 36 (dynamic inventory)**

OLD:

```text
- Dynamic inventory with the `community.digitalocean` plugin, selected by tag, authenticated with `DIGITALOCEAN_TOKEN` passed as the plugin's `oauth_token` from an env lookup (the plugin does not read that env var by default; add `tags` to its `attributes`); ...
```

NEW:

```text
- Dynamic inventory with the `community.digitalocean` plugin, selected by tag, authenticated with `DIGITALOCEAN_ACCESS_TOKEN` passed explicitly as the plugin's `oauth_token` from an env lookup, instead of relying on the plugin's default env vars (add `tags` to its `attributes`); ...
```

Rationale: unblocks Story 3.1.

### 4.3 `specs/spec-fantasy-hockey-digitalocean/stories.yaml`

**Story 1 description (line 4)**

OLD: `... and deliver DIGITALOCEAN_TOKEN as a local env var through vault.yml and bash-secrets.yml ...`

NEW: `... and deliver the vault key DIGITALOCEAN_TOKEN as the local env var DIGITALOCEAN_ACCESS_TOKEN through vault.yml and bash-secrets.yml ...`

**Story 4 description (line 19)**

OLD: `... with both existing SSH keys, pinned versions ...`

NEW: `... with the SSH key picon___id_rsa.pub (the CI key follows with the GitHub Actions stories), pinned versions ...`

**Story 5 `invoke_dev_with` (line 29)**

OLD: `... auto-mounted under /mnt/<volume-name> and survives a reboot.`

NEW: `... auto-mounted under /mnt/<volume_name> (hyphens become underscores) and survives a reboot.`

**Story 9 description (line 53)**

OLD: `... data on the volume at /mnt/<volume-name>/fantasy-hockey ...`

NEW: `... data on the volume at /mnt/prod_fantasy_hockey_data/fantasy-hockey ...`

**Line 94 (remote state story)**

OLD: `Spaces keys are separate from DIGITALOCEAN_TOKEN.`

NEW: `Spaces keys are separate from the DigitalOcean API token.`

Titles stay unchanged.

### 4.4 `specs/spec-fantasy-hockey-digitalocean/epics.md`

**E1, line 23**

OLD: ``- `DIGITALOCEAN_TOKEN` delivered through `vault.yml` and `bash-secrets.yml`.``

NEW: ``- `DIGITALOCEAN_ACCESS_TOKEN` delivered from the vault key `DIGITALOCEAN_TOKEN` through `vault.yml` and `bash-secrets.yml`.``

**E3, line 37**

OLD: ``data on the volume at `/mnt/<volume-name>/fantasy-hockey` ``

NEW: ``data on the volume at `/mnt/prod_fantasy_hockey_data/fantasy-hockey` ``

### 4.5 `planning-artifacts/epics-fantasy-hockey-digitalocean.md`

**Story 2.4 AC (line 126)**

OLD: ``**Then** one droplet `prod-fantasy-hockey…` exists (`s-1vcpu-1gb`, fra1, Ubuntu 26.04, monitoring on, tag `prod`, project `sommerfeld.io`) with both existing SSH keys``

NEW: ``**Then** one droplet `prod-fantasy-hockey` exists (`s-1vcpu-1gb`, fra1, Ubuntu 26.04, monitoring on, tag `prod`, project `sommerfeld.io`) with the SSH key `picon___id_rsa.pub` ``

**Story 2.5 AC (line 143)**

OLD: ``... a 2 GB ext4 volume is attached and mounted under `/mnt/<volume-name>` ``

NEW: ``... a 2 GB ext4 volume is attached and mounted under `/mnt/<volume_name>` (`/mnt/prod_fantasy_hockey_data`) ``

**Story 4.1 AC (line 212)**

OLD: ``... and data under `/mnt/<volume-name>/fantasy-hockey` ``

NEW: ``... and data under `/mnt/prod_fantasy_hockey_data/fantasy-hockey` ``

Story titles stay unchanged.

### 4.6 `implementation-artifacts/epic-2-context.md`

Lines 21, 22, 24, 25 — same corrections as above: scope names (`block_storage`, `reserved_ip`, `actions`), name `prod-fantasy-hockey` exactly, SSH key `picon___id_rsa.pub` (same key as local `id_rsa.pub`), mount `/mnt/prod_fantasy_hockey_data`.

Rationale: keeps the compiled Epic 2 context consistent for later readers; it is not used for new builds.

### 4.7 `planning-artifacts/architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md`

**Line 138 (pinned third-party table)**

OLD: ``version pinned in story 3.1; the inventory plugin does not read `DIGITALOCEAN_TOKEN` by default, so the token is set via `oauth_token` from an env lookup``

NEW: ``version pinned in story 3.1; the token is passed to the inventory plugin explicitly via `oauth_token` from an env lookup of `DIGITALOCEAN_ACCESS_TOKEN`, instead of relying on the plugin's default env vars``

## 5. Implementation Handoff

- **Scope:** Minor — direct implementation by the Developer agent, no backlog reorganization.
- **Executor:** Developer agent (this session), right after approval: apply 4.1–4.7, re-pad the tables, run `task lint`, commit as `docs(planning): reconcile DigitalOcean planning docs with the as-built droplet`.
- **Sprint status:** set `epic-2-retro-item-3` to `done` with the retrospective's `sprint_status.py update --set-action-status` script.
- **Success criteria:**
    - No planning artifact names `DIGITALOCEAN_TOKEN` as the env var (only as the vault key or a story title).
    - No planning artifact asks for two SSH keys or uses `/mnt/<volume-name>` as a literal path.
    - Story 3.1 can take the inventory token wiring from `platform-decisions.md` without correction.
    - `task lint` passes.
