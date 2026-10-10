---
name: 'Homelab Configs'
type: architecture-spine
purpose: build-substrate
altitude: initiative
paradigm: 'declarative-convergence (Ansible-driven, dual-verified); cloud context declared with OpenTofu + Ansible and applied by CI (AD-10)'
scope: 'Whole Homelab Configs system — brownfield, ratifying existing conventions (Ansible provisioning, InSpec compliance, observability, docs, CI safety net), plus the cloud-configs bounded context (AD-10)'
status: final
created: '2026-08-24'
updated: '2026-10-10'
binds: ['FR-1', 'FR-2', 'FR-3', 'FR-4', 'FR-5', 'FR-6', 'FR-7', 'FR-8', 'FR-9', 'CLOUD-CAP-1..CAP-8']
sources: ['../../prds/prd-configs-homelab-2026-08-24/prd.md']
companions: ['../../../specs/spec-fantasy-hockey-digitalocean/SPEC.md']
---

# Architecture Spine — Homelab Configs

## Design Paradigm

**Declarative convergence, dual-verified.** Every node's configuration is declared once, per node role (desktop, server, raspi), in Ansible. "Correct" means the node converges to that declaration — checked two independent ways: InSpec (static OS/security baseline, pass/fail on demand) and Grafana Alloy → Grafana Cloud (live telemetry, catches what a static baseline can't). The declaration is the only source of truth; nothing else maintains a parallel record of node state to reconcile against.

**Second context: cloud.** Cloud deployments under `cloud-configs/` are a separate bounded context (AD-10). OpenTofu declares the resources and its state records them, Ansible declares the software on them, and a GitHub Actions workflow on `main` applies both. They are verified by Alloy telemetry and an external synthetic check only; the InSpec baseline does not cover them.

```mermaid
graph TD
    PB["Playbooks (ansible/playbooks/*.yml)<br/>one per node role + capability playbooks"]
    RC["ansible-roles-collection (submodule)<br/>generic, reusable mechanism"]
    RL["local roles (ansible/roles/{common,grafana-cloud,media}/*)<br/>homelab-specific concrete content"]
    NODE[("Fleet node")]
    INSPEC["InSpec profile<br/>(static baseline pass/fail)"]
    ALLOY["Grafana Alloy"]
    CLOUD[("Grafana Cloud")]

    PB --> RC
    PB --> RL
    RL -. "layers on top of<br/>(same-named role)" .-> RC
    PB --> NODE
    NODE --> INSPEC
    NODE --> ALLOY --> CLOUD
```

## Invariants & Rules

### AD-1 — The Ansible declaration is the single source of truth [ADOPTED]

- **Binds:** all
- **Prevents:** node-specific configuration drifting into a separate, unreconciled state store
- **Rule:** every persistent node configuration must be expressible in and derived from the Ansible declaration (playbooks, roles, vars, inventory; vault-encrypted where secret). Cloud resources are the one place a state file is used: OpenTofu declares them and its state is their record (see AD-10). That state records cloud infrastructure only. Software and configuration on any node, cloud or fleet, stays declared in Ansible, and no other tool keeps a separate record of node reality.

### AD-2 — Ansible is the default; imperative one-offs are a narrow exception [ADOPTED]

- **Binds:** all
- **Prevents:** ad hoc imperative scripts becoming the norm for anything repeatable
- **Rule:** configuration meant to run more than once, or apply to more than one node, must be an idempotent Ansible task. Imperative shell/one-off scripts are permitted only for genuinely one-time, single-node bootstrap actions (the documented manual bootstrap steps: SSH key exchange, the sudoers workaround, Docker registry login, GitHub key setup). Each permitted manual bootstrap step must be recorded in project docs with an explicit disposition — "permanently accepted" or "tracked to close" — so no manual step is left ambiguous about whether it's meant to ever go away. *Enforcement note (Deferred):* no lint/CI gate currently distinguishes a legitimate one-off from a repeatable action wrongly written as a raw shell task inside a playbook (e.g. `repositories.yml`'s `ansible.builtin.shell: gh repo edit ...` loop) — this Rule is discipline-enforced only today.

### AD-3 — Manual node drift is tolerated transiently, not permanently [ADOPTED]

- **Binds:** all
- **Prevents:** treating every manual on-node change as an incident requiring immediate reconciliation
- **Rule:** a manual change made directly on a node is acceptable as transient/debugging state. Before it's "done," it must be captured in the Ansible declaration and re-applied. InSpec and Alloy make no promise to catch drift while it's still transient. Applies uniformly across workstations, servers, and Pi nodes. **Does not apply to AD-2's bootstrap exceptions** — those are permanently manual by design (some, like Docker registry login, are never meant to be captured into Ansible; see FR-8/§4.6) and are governed by AD-2, not this rule.

### AD-4 — Role placement: submodule owns the mechanism, local roles own the concrete content [ADOPTED]

- **Binds:** `ansible/roles/*`
- **Prevents:** reusable OS-level logic leaking into homelab-specific local roles (unreusable, untestable outside this repo) and vice versa (repo-specific config bloating the reusable collection)
- **Rule:** the test is reusability to someone else, not mechanism genericity — a role belongs in the `ansible-roles-collection` submodule when it would be generally useful to another project or user independent of this specific homelab, even if implemented generically. A role belongs in local `ansible/roles/{common,grafana-cloud,media}/*` when it exists only to serve this homelab's specific needs, even if its implementation is itself parameter-driven and generic (e.g. `common/mount-disk` takes only a UUID and a path — nothing homelab-specific in the code — but stays local, because "mount an arbitrary disk" only matters here because specific Pis have specific USB drives; no other project would want this role standalone). A local role may share a submodule role's name to layer concrete content on top of a generic mechanism (e.g. `common/taskfile-dev` on `ansible-roles-collection/taskfile-dev`) — when it does, the submodule role is always included first, the local role second. *Enforcement note (Deferred):* this ordering is discipline-enforced only — no lint checks `include_role` sequence. *Carve-out:* cloud-specific roles live under `cloud-configs/<provider>/ansible/roles` (see AD-10).

### AD-5 — Per-machine exceptions: three mechanisms, each fit to its trigger [ADOPTED]

- **Binds:** `ansible/playbooks/*`, `ansible/hosts.yml`
- **Prevents:** inventing a fourth ad hoc exception mechanism, or forcing an exception through the wrong one of the three
- **Rule:**
    - **(a) Per-host physical/hardware attachment** unique to one machine, with no accompanying service → an extra play scoped to that host, appended inside the group playbook (e.g. the pi4-0006/pi4-0005 disk-mount plays appended in `raspi.yml`, since a USB HDD is physically connected to only one Pi with no service layered on top).
    - **(b) A specific service/capability** not every node of a role needs → a playbook targeting the host(s) it applies to directly — either one named host, or the entire node-role group when the capability is opt-in and not run by the default umbrella playbook (e.g. `desktop-media.yml` targets `caprica.fritz.box` by name even though caprica is inventoried under `ubuntu_server`). **Tiebreaker with (a):** when a hardware attachment exists solely to support a specific service (e.g. caprica's mounted disks feeding `media/jellyfin`), treat the whole thing as (b) and bundle the mount into that service's playbook — (a) is reserved for hardware attachments with no accompanying service.
    - **(c) A capability that cuts across node-role groups** → a dedicated capability group in the inventory (e.g. `ollama`) carrying its own host-vars, when the capability needs per-host inventory data. When it needs no extra host-vars — just "run on the union of these groups" — an inline group-union in the playbook's `hosts:` line (e.g. `grafana-agents.yml`'s `hosts: ubuntu_desktop:ubuntu_server:raspi`) is equivalent and does not require inventing a dedicated group.

### AD-6 — Secrets: Ansible Vault only, referenced directly, one sanctioned edit path [ADOPTED]

- **Binds:** node-configuration secrets (any secret consumed by a playbook/role/task)
- **Prevents:** plaintext secrets, ad hoc per-playbook secret handling, vault files hand-edited outside the task runner
- **Rule:** all node-configuration secrets live in an Ansible Vault-encrypted file under `ansible/vars/` (e.g. `vault.yml`, `grafana-vault.yml`), referenced directly by variable name in tasks — no `vault_`-prefixed indirection layer. The only sanctioned way to edit a vault file is its `task ansible:vault[:name]` task. **Out of scope:** CI/build-time secrets consumed by GitHub Actions itself (e.g. `secrets.DOCKERHUB_TOKEN`, `secrets.GITHUB_TOKEN`) — those live in GitHub's own encrypted-secrets store, a separate and already-adequate mechanism this AD does not govern. *Carve-out:* for cloud deployments under `cloud-configs/`, the provider token and the vault password in CI are also org-level GitHub secrets (see AD-10).

### AD-7 — Dependency pinning: pin third-party, float only your own [ADOPTED]

- **Binds:** `tests/inspec/*`, the `ansible-roles-collection` submodule reference, third-party tool images referenced by `docker-compose.yml`
- **Prevents:** an upstream third party silently changing what "passing" means; over-pinning your own repos when the intent is to track latest
- **Rule:** a third-party dependency you don't control (e.g. `dev-sec/linux-baseline`, or a third-party CI tool image) is pinned to a tag/version for reproducibility. A dependency the operator also owns (e.g. `sommerfeld-io/inspec-profiles`, and the `ansible-roles-collection` submodule) may intentionally float when the intent is to always track latest — `ansible-roles-collection` does this in practice via `git submodule update --remote` in the task runner, which fast-forwards it to the latest commit on its tracked branch before every provisioning run, the same floating category as `inspec-profiles`. All four InSpec profiles' own `inspec.yml` versions are bumped together as one set. *Known gap (Deferred):* `docker-compose.yml` currently pins some third-party CI tool images (`ansible-lint`, `ls-lint`, `folderslint`, `chef/inspec`) but leaves others floating on `:latest` (`yamllint`, `lychee`) — inconsistent with this Rule; not fixed by this spine.

### AD-8 — CI division of labor: this repo validates, the roles submodule tests [ADOPTED]

- **Binds:** `.github/workflows/*`, the `ansible-roles-collection` submodule
- **Prevents:** this repo's CI growing into a redundant second role-testing matrix; assuming the submodule's CI validates this repo's own playbooks/inventory
- **Rule:** this repo's own CI performs linting, InSpec-profile vendor/validity checks, docs generation, and release. A read-only, no-target playbook syntax-check or dry-run (`--syntax-check` / `--check`, nothing applied) is compatible with this rule as a playbook-level smoke test; this repo's CI must never *apply and verify* a playbook against a live or containerized target — that would be the redundant role-testing matrix this AD prevents. Multi-Ubuntu-version role-level testing is owned exclusively by the `ansible-roles-collection` submodule's own CI. *Carve-out:* `cloud-deployment.yml` may apply OpenTofu and playbooks against live cloud resources (see AD-10); fleet playbooks are still never applied by CI.

### AD-9 — Docs mirror playbooks only [ADOPTED]

- **Binds:** `docs/ansible/*`
- **Prevents:** an expectation that every `ansible/` subdirectory needs a `docs/` counterpart
- **Rule:** every playbook under `ansible/playbooks/` has exactly one corresponding `docs/ansible/playbooks/*.md`; renaming or removing a playbook renames or removes its doc in the same change. `ansible/roles/`, `ansible/tasks/`, and `ansible/vars/` carry no docs-mirroring *requirement* — but a role doc is a permitted, narrow exception when a role has meaningful shared-variable documentation worth surfacing in the published docs site (the existing `docs/ansible/roles/grafana-cloud/alloy.md`, generated from that role's own README, is this exception in practice — not a pattern obligated to repeat for every role, but not forbidden either). *Carve-out:* cloud deployments are documented per topic under `docs/cloud/` (see AD-10).

### AD-10 — Cloud deployments are a bounded context with their own declaration [ADOPTED]

- **Binds:** `cloud-configs/*`, `.github/workflows/cloud-deployment.yml`, `docs/cloud/*`, `cloud-configs/taskfile.yml`
- **Prevents:** forcing cloud resources under fleet-node rules (which they cannot meet), and, in reverse, weakening AD-1/4/6/8/9 for fleet nodes because cloud work needed an exception
- **Rule:** a cloud deployment (the first is `cloud-configs/digital-ocean`, a DigitalOcean droplet running the fantasy hockey app) is declared in its own folder, one folder per provider, and is outside the fleet's node roles, inventory and InSpec baseline. It is declared in two layers: OpenTofu declares the cloud resources (droplet, volume, reserved IP), and Ansible under `cloud-configs/<provider>/ansible` provisions and deploys the software on them. GitHub Actions applies both. The fleet rules continue to apply unchanged to everything outside `cloud-configs/`. Carve-outs, each limited to `cloud-configs/*`:
    - **AD-1:** OpenTofu and its state are the accepted declaration of cloud resources. State is local until the remote backend is chosen in the GitHub Actions epic (the backend, and its locking support, are open); a state backup mechanism is required and comes in a later epic (see Deferred). The Ansible declaration stays the source of truth for software and configuration on the droplet. Ansible discovers cloud hosts through the provider's dynamic inventory (by tag), not through the state file or a static inventory.
    - **Apply path:** `cloud-deployment.yml` is the single CI apply path and runs only on `main`, serialized by a concurrency group so runs cannot overlap on the state lock. It applies only playbooks and OpenTofu under `cloud-configs/`. Operators may also apply from localhost.
    - **Environments and labels:** every Alloy-shipped series carries `environment` (`homelab` or `digital-ocean`); only cloud series also carry `stage` (first value `prod`). `stage` is defined once, in OpenTofu, as the droplet tag and name, and reaches Ansible only through the tag. The fleet owns `config.alloy.j2`; its only change is the added `environment=homelab` label. The fleet has no `stage` label.
    - **SSH keys:** OpenTofu is the sole owner of key injection into the droplet. Adding a key later forces a droplet replacement, which is accepted: the CI key is added when the GitHub Actions workflow is built, and the volume and reserved IP survive the replacement.
    - **Pinning:** OpenTofu, the provider (with its lock file) and the Ansible collections are third-party dependencies and are pinned per AD-7.
    - **Accepted risks:** a Dependabot bump under `cloud-configs/` may replace the droplet; existing Pi data is not migrated to the droplet.
    - **AD-4:** cloud-specific roles live under `cloud-configs/<provider>/ansible/roles`. Roles in `ansible/roles` are reused through relative paths, not `roles_path`, and are not moved. The one move is the fantasy-hockey compose role out of `ansible/roles/raspi`.
    - **AD-6:** secrets consumed by cloud playbooks are still vault-encrypted and share the one vault password. In CI, the provider token, the vault password and the CI SSH key come from organization-level GitHub secrets, because OpenTofu runs before Ansible and cannot read the vault. Locally the token is exported as an env var through `ansible/tasks/bash-secrets.yml`. Sharing the one vault password as an org secret exposes the fleet `vault.yml` to every org repo; this is accepted because the operator is the only org member, and is revisited if membership changes. Backend credentials, if a Spaces backend is chosen, are separate secrets of the same kind.
    - **AD-8:** `cloud-deployment.yml` may apply playbooks and OpenTofu against live cloud resources, because the cloud setup has no counterpart in the roles submodule's CI. It never applies fleet playbooks, and it never runs on a branch other than `main`.
    - **AD-9:** cloud docs are organized by topic, not mirrored per playbook.

## Consistency Conventions

| Concern | Convention |
| --- | --- |
| Naming (entities, files, interfaces, events) | Ansible task names follow `Category  ----  Subcategory  ----  Action` (double-space + 4-dash separators). Task-runner tasks are namespaced by colon (`ansible:ping`, `inspec:check`), mirroring the root `taskfile.yml`'s sub-taskfile `includes:`. Adding a new playbook = a new task reusing the shared `&ansible-desc`/`&ansible-cmd` YAML anchors in `ansible/taskfile.yml`. |
| Data & formats (host naming) | Workstations/servers: `<name>.fritz.box`, e.g. caprica, kobol, picon. Raspberry Pi nodes: `pi<model>-<NN>.fritz.box`, e.g. pi4-0006..05, pi5-0004. |
| State & cross-cutting (mutation, secrets, drift verification) | State ownership: AD-1. Secrets: AD-6. Drift verification is dual and independent (InSpec static baseline + Grafana Alloy live telemetry) — neither claims to be the sole source of truth on "is this node correct." |

## Stack

| Name | Version |
| --- | --- |
| `ansible-roles-collection` (submodule) | floating — tracks latest via `git submodule update --remote` (snapshot at time of writing: `v0.15.0-5-gea3ab01`) |
| InSpec (CI runner image, `chef/inspec`) | 5.22.76 |
| InSpec profile spec version (all 4 profiles, bumped together) | 0.92.1 |
| `dev-sec/linux-baseline` (InSpec dependency) | tag `2.9.0` (pinned) |
| `sommerfeld-io/inspec-profiles` (InSpec dependency) | branch `main` (intentionally floating) |
| `ansible-lint` (CI image, pipelinecomponents; the number is the image version, not ansible-lint's own) | 0.79.33 |
| go-task (Taskfile schema) | 3.42.1 |
| OpenTofu (cloud context) | 1.12.x line (verified current 2026-10-10; exact version pinned in `required_version` in story 2.4) |
| OpenTofu `digitalocean` provider (cloud context) | version and lock file pinned in story 2.4 |
| `community.digitalocean` Ansible collection (cloud context) | version pinned in story 3.1; the inventory plugin does not read `DIGITALOCEAN_TOKEN` by default, so the token is set via `oauth_token` from an env lookup |

## Structural Seed

```text
ansible/
  playbooks/   # one per node role (desktop/server/raspi) + capability playbooks (ollama, grafana-agents) + utility (ping, scan, cleanup)
  roles/
    ansible-roles-collection/   # git submodule — generic, reusable mechanism (~24 roles)
    common/                     # local — concrete homelab content (e.g. taskfile-dev, mount-disk)
    grafana-cloud/               # local — alloy, exporters
    media/                       # local — jellyfin
  tasks/       # shared task fragments (e.g. vault secret loading)
  vars/        # main.yml, raspi.yml, ubuntu.yml, vault.yml, grafana-vault.yml
  hosts.yml    # inventory: ubuntu_desktop, ubuntu_server, raspi (node-role groups) + ollama (cross-cutting capability group)
               # VMs: no distinct VM group — a VM guest is inventoried under whichever node-role group matches its OS,
               # same declarative rules as any physical node. The submodule's `virtualization` role sets up the
               # *hypervisor* (currently on caprica); it does not itself declare/converge any VM guest's configuration.
tests/inspec/
  desktop-baseline/, server-baseline/, raspi-baseline/, ollama/   # inspec.yml + controls/includes.rb, depends: on external profiles
cloud-configs/
  taskfile.yml         # included in the root taskfile with prefix `cloud`
  digital-ocean/
    opentofu/          # droplet, reserved IP, volume (AD-10)
    ansible/           # dynamic inventory, provision.yml, deploy-services.yml, cloud-specific roles
docs/
  ansible/playbooks/   # 1:1 mirror of ansible/playbooks/ (AD-9)
  nodes/               # mirrors inventory groups, not an ansible/ directory
  cloud/digital-ocean/ # cloud docs organized by topic (AD-10)
```

**Deployment & environment:** two environments. The fleet is the live homelab itself (3 Ubuntu workstations/servers, 5 Raspberry Pi nodes, VMs) with no dev/staging tier (`environment=homelab`). The cloud context is one DigitalOcean droplet, `stage=prod` (`environment=digital-ocean`); further stages (for example test) are possible later and are keyed by the droplet tag. External providers: Grafana Cloud (observability sink), GitHub (repo hosting, Actions CI, release, and the apply path for the cloud context) and DigitalOcean (cloud resources).

```mermaid
graph TD
    subgraph Inventory Groups
        UD["ubuntu_desktop<br/>kobol, picon"]
        US["ubuntu_server<br/>caprica"]
        RP["raspi<br/>pi4-0006, pi4-0005, pi4-0002, pi4-dradis, pi5-0004"]
        OL["ollama (cross-cutting)<br/>caprica, picon"]
    end
    OP(["Operator<br/>runs ansible-playbook locally"])
    GH[("GitHub<br/>hosts code + lint/validate CI + release<br/>never applies fleet playbooks — see AD-8")]
    GC[("Grafana Cloud<br/>observability")]
    OT["OpenTofu + cloud Ansible<br/>cloud-configs/digital-ocean (AD-10)"]
    DO[("DigitalOcean droplet<br/>environment=digital-ocean, stage=prod")]

    GH -. "applies on main only" .-> OT
    OP -. "may also apply locally" .-> OT
    OT --> DO
    DO --> GC
    GH -. "hosts declaration for" .-> OP
    OP -- "applies playbook to" --> UD
    OP -- "applies playbook to" --> US
    OP -- "applies playbook to" --> RP
    UD --> GC
    US --> GC
    RP --> GC
```

## Capability → Architecture Map

| Capability / Area | Lives in | Governed by |
| --- | --- | --- |
| FR-1 Provision a node via its role's playbook | `ansible/playbooks/{desktop,server,raspi}.yml` | Design Paradigm, AD-1, AD-2 |
| FR-2 Per-machine exceptions | `ansible/playbooks/*.yml`, `ansible/hosts.yml` | AD-5 |
| FR-3 Compliance check on demand | `tests/inspec/*/` | AD-7, Design Paradigm (dual verification) |
| FR-4 Live telemetry / observability | `ansible/roles/grafana-cloud/alloy` | Design Paradigm (dual verification) |
| FR-5 Catch role regressions before a real node | `ansible-roles-collection` submodule's own CI | AD-8 |
| FR-6 Isolate in-progress fixes from running nodes | git branching workflow | Deferred — standard git practice, not a system-specific invariant |
| FR-7 Docs stay structurally aligned | `docs/ansible/playbooks/*.md` | AD-9 |
| FR-8 Manual steps documented, not hidden | project docs | AD-2 |
| FR-9 Close the sudoers NOPASSWD gap (#160) | GitHub issue #160 | Deferred — scoped to that issue, not an architecture invariant |
| Cloud CAP-1 Droplet, reserved IP, volume via OpenTofu | `cloud-configs/digital-ocean/opentofu` | AD-1, AD-10 |
| Cloud CAP-2 Provision droplet software, dynamic inventory | `cloud-configs/digital-ocean/ansible` | AD-4, AD-10 |
| Cloud CAP-3 Deploy the app as docker compose | `cloud-configs/digital-ocean/ansible/roles` | AD-10 |
| Cloud CAP-4 Observability and labels | `ansible/roles/grafana-cloud/alloy`, `grafana-cloud/manifests/git-sync/apps` | AD-10 (label contract) |
| Cloud CAP-5 CI apply path | `.github/workflows/cloud-deployment.yml` | AD-6, AD-8, AD-10 |
| Cloud CAP-6 Taskfile and linters | `cloud-configs/taskfile.yml`, `.github/workflows/pipeline.yml` | AD-10 |
| Cloud CAP-7 Docs | `docs/cloud/digital-ocean` | AD-9, AD-10 |
| Cloud CAP-8 Droplet replacement | `cloud-configs/digital-ocean/opentofu` | AD-10 |

## Deferred

- **"GitHub issue #172"** (most provisioning playbooks excluded from `ansible-lint` due to vault-file references) — the underlying tech debt is real (verified in `.ansible-lint.yml`'s `exclude_paths`), but issue #172 itself does not resolve in this repo's tracker (may be renumbered/deleted/transferred) — the reference is stale. Not resolved by this spine; the operator should confirm/replace the tracking issue separately.
- **GitHub issue #160** (sudoers NOPASSWD workaround) — implementation detail scoped to that issue.
- **Chef/InSpec ecosystem EOL risk** — Chef Infra Server EOL Nov 2026 confirmed current. InSpec 5.x EOL is **not** Apr 2026 as the PRD states — Chef's current support matrix gives 2027-08-31, over a year further out than the PRD assumed (verified via web research during this spine's reviewer gate). Not a live risk today; revisit if/when it becomes a practical problem. The PRD's EOL date should be corrected in a follow-up PRD update (see below).
- **Maintenance-burden signal** — explicitly declined in the PRD; not re-litigated here.
- **`ansible-core`/control-environment version pinning** — no explicit in-repo pin found beyond the devcontainer's installed version; not architecturally load-bearing enough to block this spine. Revisit if a version-drift incident actually occurs.
- **AD-2 enforcement gap** — no lint/CI mechanism distinguishes a legitimate Ansible task from a repeatable action wrongly written as a raw shell command inside a playbook (concrete existing example: `repositories.yml`'s `gh repo edit` shell loop). Discipline-enforced only; not resolved by this spine.
- **AD-4 role-inclusion ordering gap** — the "submodule role before local role" ordering for same-named role pairs is not checked by any lint; discipline-enforced only.
- **AD-7 pin/float inconsistency in `docker-compose.yml`** — `yamllint` and `lychee` CI images float on `:latest` while other tool images are pinned; inconsistent with AD-7's rule, not fixed by this spine.
- **OpenTofu state backup (cloud)** — required and important, but delivered in a later epic. Until then state stays local, which is a single copy on the operator's machine. The remote backend (DO Spaces is the candidate; its locking support is unconfirmed) is chosen in the GitHub Actions epic.
- **AD-8 versus the existing `molecule` CI job** — `pipeline.yml`'s `molecule` job applies roles to containers, which AD-8's "never apply and verify" wording does not allow. Pre-existing and not caused by AD-10; not resolved by this spine.
- **Cloud operations** — unattended-upgrades, logrotate and disk cleanup, memory limits, the post-deploy smoke test and backup of the app's data file are planned in later cloud epics and are not placed here.
- **Reuse of fleet roles by the cloud context** — roles in `ansible/roles` are reused via relative paths and are an unmanaged interface: a fleet-role edit can change a cloud apply. Discipline-enforced only.
- **PRD follow-up corrections** — two items the PRD should be updated to match reality/this spine, batched for a single future PRD touch: (1) FR-7 currently overclaims a full `ansible/`-to-`docs/` mirror; AD-9 above states the real (narrower, playbooks-only) rule. (2) The Chef/InSpec Non-Goal's stated InSpec 5.x EOL date (Apr 2026) should be corrected to Aug 2027 per the version check above.
