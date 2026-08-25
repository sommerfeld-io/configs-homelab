---
title: Homelab Configs
created: 2026-08-24
updated: 2026-08-24
status: final
---

# PRD: Homelab Configs

## 0. Document Purpose

This PRD formalizes Homelab Configs: a solo-operator, Ansible-driven Infrastructure-as-Code system that has already been running this homelab fleet for two years. It exists to give downstream work (architecture notes, epics/stories, future PRD updates) a stable, FR-referenced description of what the system does today and what's explicitly next — not to pitch a new idea. It builds directly on `prfaq-configs-homelab.md` and its distillate (`prfaq-configs-homelab-distillate.md`), which already carry the founding narrative, rejected alternatives, and scope decisions in more depth than is repeated here — this PRD distills those into requirements and does not re-litigate them. Depth is kept light per hobby/internal-tool calibration (confirmed) — feature and FR sections are deliberately terse, and heavier PRD clusters (compliance registers, rollout plans, business case) are omitted as not applicable to a single-operator personal system.

## 1. Vision

Homelab Configs turns "setting up a machine" from a remembered ritual into a run command. Every workstation, Raspberry Pi, and VM in the fleet is defined, provisioned, and verified as code, so a machine is either running its declared setup or the automation says so — not "probably." The payoff isn't a time-savings number; it's consistency (every machine of a kind installs identically) and disposability (machines become cheap to rebuild or discard rather than precious and hand-tuned — cattle, not pets). This matters because of two incidents that made the problem impossible to ignore: containers meant to behave identically across hosts didn't, and a Raspberry Pi silently lost NTP sync for weeks — by the time it was noticed, every other Pi in the fleet had the same problem, invisibly. Manual setup produces snowflakes that drift apart quietly; Homelab Configs is the answer to that.

> "Every machine should look the same after setup, every time. If I have to remember something to make that true, the automation isn't done yet."
> — Sebastian, Creator & Operator

<!-- -->

> "I found one Pi had drifted on time sync. I checked the others expecting them to be fine. They weren't — every one had the exact same problem, I just hadn't looked yet. I fixed it everywhere in the time it took to run one Ansible command."
> — Sebastian, on the incident that convinced him this had to be code, not memory

## 2. Target User

### 2.1 Jobs To Be Done

- As the sole operator of a mixed fleet (3 Ubuntu workstations/servers, 5 Raspberry Pi nodes, and VMs), I want to provision or rebuild any machine identically to its peers, so I never have to remember setup steps.
- As the same person who builds and runs this system, I want a straight answer — pass or fail — to "does this machine still match its declared baseline?" instead of having to guess.
- I want machines to be disposable: if one misbehaves or an experiment calls for a clean slate, rebuilding costs a command, not an afternoon.
- I want a documented boundary around what stays manual by choice (one-off, low-value, or credential-risk-avoiding steps), so "manual" reads as a deliberate decision, not an unfinished gap.

### 2.2 Non-Users (v1)

- Other homelab operators looking to adopt or fork this repo wholesale. The repo is public for visibility (including as a future job-application talking point), but reuse/contribution is a tolerated side effect, not a design goal — it is opinionated and will overwrite an adopter's existing config.
- Anyone needing bare-metal provisioning (SD-card imaging, first-boot setup). That is a distinct, explicitly out-of-scope problem space (tools like cloudmesh-pi-burn or MAAS target it).

*Key User Journeys are omitted: this is a single-operator internal tool where the operator is also the builder, so a standalone journeys section would restate the JTBD above rather than add information.*

## 3. Glossary

- **Node** — Any managed machine in the fleet: an Ubuntu workstation/server or a Raspberry Pi. VMs are nodes too.
- **Fleet** — The full set of nodes: caprica, kobol, picon (workstations/servers), pi4-01/02/03/05 and pi5-01 (Raspberry Pi), plus VMs. All current Pi nodes run Ubuntu (Server or Desktop); Raspberry Pi OS remains a deliberately supported target for a possible future Pi node that needs a desktop environment, even though no current node uses it.
- **Role** (node role) — The category a node belongs to for provisioning purposes: desktop, server, or raspi. Determines which playbook and InSpec profile apply.
- **Ansible role** — A reusable, versioned unit of provisioning logic in the `ansible-roles-collection` submodule (packages, shell config, filesystem, Docker, dev tools, Grafana Alloy, repo cloning, cleanup, ClamAV, hardening, etc.). Distinct from "node role" above — context disambiguates.
- **Playbook** — An Ansible entry point that applies one or more Ansible roles to nodes of a given node role.
- **Baseline** — The declared, InSpec-checked OS/security configuration a node of a given role must satisfy.
- **Drift** — A node's actual state diverging from its baseline or its playbook's declared configuration.
- **Host group** — An Ansible inventory grouping used to scope a playbook to a subset of nodes, including per-machine exceptions.
- **Disposability** — The property that a node can be wiped and rebuilt from its playbook at low cost, because its configuration is fully defined as code rather than hand-tuned.

## 4. Features

### 4.1 Fleet Provisioning (Ansible)

**Description:** One playbook per node role (desktop, server, raspi) installs packages, shell configuration, dev tooling, containers, hardening, and monitoring in a single pass. Running the matching playbook is the entire provisioning step after the OS installer and a light pass of GNOME tweaks. Roles live in a separate git submodule (`ansible-roles-collection`, ~24 roles) so provisioning logic is versioned and testable independently of node-specific playbooks/inventory.

**Functional Requirements:**

#### FR-1: Provision a node via its role's playbook

The operator can run the playbook matching a node's role (desktop, server, or raspi) to bring that node to its full declared configuration in one pass.

**Consequences (testable):**

- Running the role's playbook against a freshly OS-installed node requires no manual step beyond the accepted manual bootstrap steps (§4.6).
- Two nodes of the same role, provisioned from the same playbook run, converge to the same configuration.

#### FR-2: Support deliberate per-machine exceptions

The operator can make one node differ on purpose (e.g., a test server with an extra tool) via a dedicated host group or a playbook scoped to that one machine, without changing the shared role definition.

**Consequences (testable):**

- A node in a dedicated host group or scoped playbook receives its exception without any change to the shared role definition used by other nodes of the same role.

**Out of Scope:**

- Ad-hoc, undocumented manual changes to a single node outside of a host group/scoped playbook — that reintroduces the snowflake problem this system exists to prevent.

**Feature-specific NFRs:**

- Secrets used during provisioning are stored only via Ansible Vault (encrypted, safe to commit) — never in plaintext in the repo.

### 4.2 Compliance Verification (InSpec)

**Description:** Four InSpec profiles (desktop-baseline, server-baseline, raspi-baseline, ollama) check a node against its declared OS/security baseline, layering the community `dev-sec/linux-baseline` (pinned) with the org's own `sommerfeld-io/inspec-profiles`. Scope is deliberately limited to the OS/security baseline — see §5 Non-Goals for what this deliberately doesn't cover.

**Functional Requirements:**

#### FR-3: Check a node against its baseline on demand

The operator can run the InSpec profile matching a node's role and get a pass/fail result against the declared OS/security baseline.

**Consequences (testable):**

- A passing run means the node satisfies its role's InSpec profile; it does not mean the node is free of any possible drift outside that profile's scope.

**Out of Scope:**

- Detecting application-level or cross-host consistency drift (e.g., Docker behavior differing between hosts). See §5 Non-Goals.

### 4.3 Observability (Grafana Alloy)

**Description:** Every node runs a Grafana Alloy agent reporting to Grafana Cloud. This is a second, independent safety net alongside InSpec: it was a Grafana alert, not manual discovery or a compliance check, that first caught the motivating NTP-drift incident.

**Functional Requirements:**

#### FR-4: Every node reports live telemetry

Once provisioned, a node continuously reports operational telemetry (including clock/time sync health) to Grafana Cloud, without requiring the operator to be logged into that node to notice a problem.

**Consequences (testable):**

- An alertable condition on any node (e.g., NTP desync) surfaces in Grafana Cloud without the operator manually checking that node first.

### 4.4 Automation Safety Net (CI + Git Branching)

**Description:** The `ansible-roles-collection` submodule runs its own CI test matrix against multiple Ubuntu versions, on every push and weekly — surfacing the most likely failure mode (an Ubuntu upgrade breaking role assumptions) in a virtual environment before a broken role reaches a real node. Because everything lives in git, a broken role gets fixed on a branch without ever touching machines running the last-known-good configuration. This discipline — version control, code review, and CI — is a deliberate choice over ad hoc shell scripts, which wouldn't provide the same audit trail or safety net for a fleet this size.

**Functional Requirements:**

#### FR-5: Catch role regressions before they reach a real node

Changes to an Ansible role are exercised by an automated, multi-Ubuntu-version test matrix on every push and on a weekly schedule, independent of any real node being touched.

**Consequences (testable):**

- A role change that breaks a supported Ubuntu version fails CI before merge, rather than being discovered by provisioning a real node.

#### FR-6: Isolate in-progress fixes from running nodes

A role fix in progress lives on a branch; nodes already provisioned from the last-known-good configuration are unaffected until that branch is merged and re-applied.

**Consequences (testable):**

- Nodes already provisioned from the last-known-good configuration show no change until the fix branch is merged and its playbook is re-applied.

### 4.5 Documentation (MkDocs)

**Description:** Docs (MkDocs, Material theme) mirror the `ansible/` structure, so playbooks, roles, and profiles are discoverable and presentable — this also serves the secondary, previously-unstated motivation of the public repo being a polished portfolio/talking-point artifact, not purely private utility.

**Functional Requirements:**

#### FR-7: Docs stay structurally aligned with automation

The docs tree mirrors the `ansible/` directory structure: every top-level `ansible/` directory has a corresponding `docs/` directory of the same name, so a new playbook or role has a defined, discoverable place for its documentation to live.

**Consequences (testable):**

- Every top-level directory under `ansible/` has a same-named counterpart under `docs/`.

### 4.6 Manual Bootstrap Steps (Accepted, Documented, Closed)

**Description:** A small set of steps stays manual by deliberate choice, not oversight: OS installer + GNOME tweaks, SSH key exchange, a sudoers NOPASSWD workaround needed on newer Ubuntu (tracked, see FR-9), Docker registry login (automating it would mean storing credentials somewhere — not worth the risk for a one-off task), and GitHub key setup. This list is closed — confirmed with the user, nothing further is being added.

**Functional Requirements:**

#### FR-8: Manual steps are documented, not hidden

Every currently-manual bootstrap step is named in project docs as deliberately manual, distinguishing steps that are permanently accepted from the one currently tracked to close (FR-9).

**Consequences (testable):**

- Every item in the manual-steps list (§4.6) is tagged either "permanently accepted" or "tracked to close"; no item is left untagged.

**Non-Goals:**

- Automating Docker registry login. See §5.

### 4.7 Near-Term Follow-Up

**Description:** Of the items the PRFAQ's verdict flagged as "needs more heat," only one is an active near-term requirement. The other two were considered and explicitly declined as requirements — see §5 Non-Goals for why.

**Functional Requirements:**

#### FR-9: Close the sudoers NOPASSWD gap (GitHub issue #160)

The sudoers NOPASSWD workaround needed on newer Ubuntu versions is resolved so it no longer appears in the manual-steps list (§4.6).

**Consequences (testable):**

- GitHub issue #160 is closed.
- The docs' manual-steps list no longer includes the sudoers workaround.

## 5. Non-Goals (Explicit)

- **Bare-metal Pi provisioning** (SD-card imaging, first-boot setup) — a distinct problem space handled by tools like cloudmesh-pi-burn/MAAS; Homelab Configs governs from first boot onward only.
- **Expanding InSpec's scope** to catch the specific incidents that motivated this project (NTP sync, cross-host Docker consistency) — compliance stays honestly scoped to the OS/security baseline; observability (§4.3) is the layer that actually caught the NTP incident.
- **Automating Docker registry login** — rejected; would require storing credentials somewhere (worst case, in-repo), which isn't worth the risk for a once-per-machine task.
- **Formal backup/recovery tooling** beyond what already exists — GitHub backs up the repo, Ansible can recreate SSH keys, and password-based node login is a fallback. Disposability-by-design is the accepted recovery strategy. The one residual gap this doesn't close: the vault and sudo passwords themselves have to be remembered somewhere — an accepted, bounded risk, not a solved problem.
- **Seeking outside contributions or adoption** — the repo stays public for visibility, not community growth; the README's warning against direct reuse stands.
- **Opening a Chef/InSpec ecosystem EOL tracking issue now** — the Chef Infra Server (Nov 2026) and InSpec 5.x (Apr 2026) EOL dates are a real but explicitly deferred risk. Current InSpec usage works fine as-is; this will be dealt with when it becomes an actual problem, not preemptively.
- **A dedicated maintenance-burden signal/mechanism** — considered and declined. Noticing when maintaining this repo is getting heavy already happens naturally as part of how the project is run; a formal indicator would be solving a problem that doesn't exist.

## 6. MVP Scope

*"MVP" here means the current, already-operational baseline plus the near-term follow-up — there is no pre-launch/post-launch split for a two-year-old running system.*

### 6.1 In Scope

- Fleet provisioning via role-matched Ansible playbooks (FR-1, FR-2)
- Compliance verification via role-matched InSpec profiles (FR-3)
- Observability via Grafana Alloy → Grafana Cloud (FR-4)
- CI safety net + git-branch isolation for role changes (FR-5, FR-6)
- Docs mirroring the ansible/ structure (FR-7)
- Documented, closed manual bootstrap steps (FR-8)
- Closing #160 (FR-9)

### 6.2 Out of Scope for MVP

- Any item listed under §5 Non-Goals — these are not deferred, they are rejected, structurally out of bounds, or explicitly declined as premature.
- Formal time-savings measurement — no metric exists or is planned; qualitative confidence only (see §7).

## 7. Success Metrics

*Kept deliberately qualitative (confirmed) — the PRFAQ explicitly rejected a fabricated time-savings number, no measurement infrastructure for that exists, and none is planned; the user confirmed this framing carries forward without new quantitative targets.*

**Primary**

- **SM-1**: A node reinstalled via its role's playbook reaches full baseline compliance (its InSpec profile passes) with no manual intervention beyond the documented accepted steps (§4.6). Validates FR-1, FR-3, FR-8.
- **SM-2**: Drift found on one node of a role is corrected fleet-wide (all nodes of that role) via a single Ansible run once identified. Validates FR-1, FR-5, FR-6.

**Secondary**

- **SM-3**: Issue #160 is closed and no longer appears in the docs' manual-steps list. Validates FR-9.

**Counter-metrics (do not optimize)**

- **SM-C1**: Do not chase automating every remaining manual step just to reach "100% automated" — several are deliberately manual because automating them (e.g., Docker registry login) would introduce credential-storage risk disproportionate to the one-off task they replace. Counterbalances SM-1.

## 8. Open Questions

None at this time.

## 9. Assumptions Index

None — the two items previously tracked here are now confirmed decisions, stated in §0 and §7.
