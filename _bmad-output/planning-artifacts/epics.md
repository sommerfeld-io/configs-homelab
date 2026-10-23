---
stepsCompleted: [1, 2, 3]
inputDocuments: ['prds/prd-configs-homelab-2026-08-24/prd.md', 'architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md', '../specs/spec-configs-homelab/SPEC.md', '../specs/spec-configs-homelab/glossary.md']
---

# Homelab Configs - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Homelab Configs, decomposing the requirements from the PRD, Architecture spine, and the distilled Spec (SPEC.md + glossary.md) into implementable stories. Brownfield context: this is a 2-year-old, already-running system — most FRs describe capabilities that already exist and are being formalized/hardened, not built from zero. FR9 is tracked directly via existing GitHub issue #160, not via a BMad story — no need to duplicate that tracking here.

## Requirements Inventory

### Functional Requirements

FR1: Operator can provision or rebuild any node to its full declared configuration in one pass by running the playbook matching its role (desktop, server, or raspi); requires no manual step beyond the accepted bootstrap list, and two nodes of the same role converge to the same configuration. (SPEC CAP-1 / PRD FR-1)
FR2: Operator can make one node differ on purpose via a dedicated host group or a playbook scoped to that machine, without changing the shared role definition used by other nodes of that role. (SPEC CAP-2 / PRD FR-2)
FR3: Operator can check any node against its role's declared OS/security baseline on demand, via the matching InSpec profile, returning pass/fail. (SPEC CAP-3 / PRD FR-3)
FR4: Every node continuously reports operational telemetry (including clock/time-sync health) to Grafana Cloud, so an alertable condition surfaces without the operator manually checking the node. (SPEC CAP-4 / PRD FR-4)
FR5: Changes to an Ansible role are exercised by an automated, multi-Ubuntu-version test matrix before ever touching a real node; a breaking change fails CI before merge. (SPEC CAP-5 / PRD FR-5)
FR6: An in-progress role fix stays isolated (via git branching) from nodes already running the last-known-good configuration until the fix is merged and re-applied. (SPEC CAP-6 / PRD FR-6)
FR7: Docs stay structurally aligned with `configs-homelab/ansible/playbooks/` — exactly one doc per playbook, kept in sync when a playbook is renamed or removed. (SPEC CAP-7 / PRD FR-7, corrected scope per Architecture AD-9 — playbooks only, not every configs-homelab/ansible/ subdirectory)
FR8: Every currently-manual bootstrap step (SSH key exchange, sudoers workaround, Docker registry login, GitHub key setup) is documented with an explicit disposition — "permanently accepted" or "tracked to close" — with none left untagged. (SPEC CAP-8 / PRD FR-8)
FR9: The sudoers NOPASSWD workaround needed on newer Ubuntu versions is resolved so it no longer appears in the manual-steps list. (SPEC CAP-9 / PRD FR-9) — tracked directly via GitHub issue #160; no BMad story needed.
FR10: Every homelab node (desktops, servers, Raspberry Pis) reports its Wi-Fi link quality (signal strength, bitrates, retries, failures) to Grafana Cloud through the node_exporter wifi collector in its Alloy config, shown on a "Wi-Fi" dashboard; cloud droplets are excluded. (SPEC CAP-10 / PRD FR-10)

### NonFunctional Requirements

NFR1: All node-configuration secrets go through Ansible Vault only, referenced directly by variable name — no plaintext, no ad hoc per-playbook secret handling. CI/build-time secrets (GitHub Actions' own encrypted store) are a separate, already-adequate mechanism, out of this scope. (SPEC Constraint 1 / Architecture AD-6)
NFR2: Progress/success measurement stays qualitative only — no time-savings instrumentation or dashboard is in scope for any story below. (SPEC Constraint 2)
NFR3: Architecture invariants in ARCHITECTURE-SPINE.md (AD-1 through AD-9) are binding for all implementation work — summarized in Additional Requirements below. (SPEC Constraint 3)

### Additional Requirements

**No starter template** — this is a brownfield system already running for 2 years; there is no Epic 1 "scaffold a new project" story. Epic 1 instead formalizes/hardens what already exists.

From the Architecture spine (binding invariants, AD-1 through AD-9):

- **AD-1 (state ownership):** every persistent node configuration must be expressible in and derived from the Ansible declaration (playbooks/roles/vars/inventory, vault-encrypted where secret). No tool with its own separate state store (e.g. Terraform-style) is the source of truth.
- **AD-2 (Ansible is default):** anything repeatable/multi-node must be an idempotent Ansible task; imperative one-offs are permitted only for the four named bootstrap exceptions, each of which must carry a documented disposition (feeds FR8/FR9 directly).
- **AD-3 (manual drift):** a manual on-node change is acceptable as transient/debugging state but must be captured into the declaration before it's "done" — except AD-2's permanent bootstrap exceptions, which this rule does not apply to.
- **AD-4 (role placement):** a role goes in the `ansible-roles-collection` submodule only if it would be generally useful to another project/user independent of this homelab; otherwise it stays in local `configs-homelab/ansible/roles/*`. A local role may layer on a same-named submodule role (submodule included first).
- **AD-5 (per-machine exceptions):** three mechanisms, each fit to its trigger — (a) host-scoped extra play in the group playbook for a standalone hardware attachment, (b) a playbook targeting the host(s) by name or whole-group for a specific service/capability, (c) a dedicated capability group (with host-vars) or inline group-union for a cross-node-role capability.
- **AD-6 (secrets):** see NFR1.
- **AD-7 (dependency pinning):** third-party dependencies are pinned (tag/version) for reproducibility; dependencies the operator owns may intentionally float to track latest.
- **AD-8 (CI division of labor):** this repo's CI lints, validates InSpec profiles, builds docs, and releases — it must never apply a playbook against a live/containerized target (a read-only syntax-check/dry-run is fine). Multi-Ubuntu-version role testing lives only in the `ansible-roles-collection` submodule's own CI.
- **AD-9 (docs mirror):** every playbook has exactly one `docs/ansible/playbooks/*.md` counterpart, kept in sync on rename/delete (feeds FR7 directly). Roles/tasks/vars carry no mirroring requirement (a narrow existing exception for `grafana-cloud/alloy` is permitted, not obligatory elsewhere).

**Deployment/infra:** single environment — the live homelab fleet itself, no dev/staging tier. External providers: Grafana Cloud (observability) and GitHub (repo hosting, Actions CI, release). No integration, data-migration, or API-versioning requirements apply (personal infra, not a service with external consumers).

### UX Design Requirements

None — no UI. This is a CLI/automation project (Ansible playbooks, InSpec profiles, a task runner); the "interface" is the command line and generated docs.

### FR Coverage Map

FR1: Already delivered, no epic - fleet provisioning via role playbooks, ratified as-is by the architecture spine
FR2: Already delivered, no epic - per-machine exceptions (AD-5), ratified as-is
FR3: Already delivered, no epic - InSpec compliance check on demand, ratified as-is
FR4: Already delivered, no epic - Grafana Alloy live telemetry, ratified as-is
FR5: Already delivered, no epic - ansible-roles-collection submodule's own CI test matrix, ratified as-is
FR6: Already delivered, no epic - git-branch isolation, ratified as-is
FR7: Already delivered, no epic - docs-mirrors-playbooks (AD-9), ratified as-is
FR8: Epic 1 - tag every manual bootstrap step with an explicit disposition
FR9: No BMad story - already tracked directly via GitHub issue #160
FR10: Epic 9 - Wi-Fi collector in the homelab Alloy config and the Wi-Fi dashboard

## Epic List

### Epic 1: Close the Bootstrap Debt
Every manual bootstrap step has an explicit, auditable disposition.
**FRs covered:** FR8

### Epic 9: Wi-Fi telemetry for homelab nodes
Wi-Fi drops on homelab nodes can be correlated with signal strength and link quality in Grafana Cloud. Homelab only: nothing under configs-cloud changes. Added 2026-10-22 (sprint-change-proposal-2026-10-22); runs after Epic 8 and before Epic 6 (epics-fantasy-hockey-digitalocean.md).
**FRs covered:** FR10

## Epic 1: Close the Bootstrap Debt

Every manual bootstrap step has an explicit, auditable disposition.

### Story 1.1: Tag every manual bootstrap step with an explicit disposition

As an operator,
I want every manual bootstrap step in the docs to carry an explicit "permanently accepted" or "tracked to close" tag,
So that no manual step is ambiguous about whether it's meant to go away.

**Acceptance Criteria:**

**Given** the setup-guide checklist in `docs/nodes/*/index.md`
**When** I read the entries for SSH key exchange, the sudoers workaround, Docker registry login, and GitHub key setup
**Then** each one carries an explicit disposition tag ("permanently accepted" or "tracked to close")
**And** no manual step entry is left untagged

**Given** a manual step is tagged "tracked to close"
**When** I look for its tracking reference
**Then** a linked GitHub issue number is present (e.g. issue #160 for the sudoers workaround)

## Epic 9: Wi-Fi telemetry for homelab nodes

Wi-Fi drops on homelab nodes can be correlated with signal strength and link quality in Grafana Cloud.

### Story 9.1: Enable the Wi-Fi collector in the homelab Alloy config

As an operator,
I want every homelab node's Alloy to export Wi-Fi metrics,
So that a connection drop can be correlated with the link quality at that time.

**Acceptance Criteria:**

**Given** `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2`
**When** the change is made
**Then** `prometheus.exporter.unix "integrations_node_exporter"` enables the `wifi` collector, `task lint` passes (including `lint-alloy-config`), and nothing under `configs-cloud/` changes (the droplet keeps its own template)

**Given** `grafana-agents.yml` applied to the fleet (operator)
**When** Grafana Cloud is queried
**Then** pi4-0002 reports `node_wifi_station_signal_dbm` and the other `node_wifi_*` series for its Wi-Fi interface, every node that has a Wi-Fi interface is listed with its result, and nodes without Wi-Fi still scrape without collector errors

**Given** the change
**When** it is done
**Then** the Alloy role README (copied to docs by `task docs:generate`) says which collector is on, which metrics it gives, and that no `iw` or `wireless-tools` package is needed

### Story 9.2: Wi-Fi dashboard in the Git Sync folder network

As an operator,
I want a Wi-Fi dashboard in Grafana Cloud,
So that I see the link quality of every Wi-Fi node at a glance and next to its drops.

**Acceptance Criteria:**

**Given** the `node_wifi_*` series from Story 9.1
**When** the dashboard "Wi-Fi" is added as `grafana-cloud/manifests/git-sync/network/` (with `_folder.json`)
**Then** it shows per node and interface: signal strength (dBm), receive and transmit bitrate, transmit retries and failures, beacon loss, connected SSID/BSSID, and a node variable, and the Git Sync resource count stays within the Free plan limit of 20 (13 after this story)

**Given** the dashboard merged to `main`
**When** Git Sync has run
**Then** the dashboard is visible in Grafana Cloud under the folder `network` with data from pi4-0002; the story stays in `review` until this was observed (AGENTS.md pitfall)

**Given** the change
**When** it is done
**Then** the dashboard is documented next to the other Grafana Cloud docs
