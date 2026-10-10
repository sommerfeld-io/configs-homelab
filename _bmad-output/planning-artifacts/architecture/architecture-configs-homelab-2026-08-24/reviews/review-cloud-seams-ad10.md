# Seam review — AD-10 cloud carve-outs

Reviewed: ARCHITECTURE-SPINE.md (AD-1, 4, 6, 8, 9, 10, paradigm, diagrams), SPEC.md, epics.md, platform-decisions.md (grep only), ansible/tasks/bash-secrets.yml, ansible/taskfile.yml, ansible/playbooks/raspi.yml, .github/workflows/pipeline.yml, .github/dependabot.yml, grafana-cloud alloy template.

Verdict: AD-10 is a sound bounded-context rule, but the carve-outs leak into the fleet in three places the spine does not admit (Alloy label, role move out of raspi, vault edit path), AD-10 leaves state/stage/apply-authority undecided, and the paradigm text and diagrams still describe a single-context system.

## High

### H1. The `environment` label change leaks into fleet nodes, outside any carve-out

- epics E2 / platform-decisions: `environment=homelab` is added to the homelab `config.alloy.j2`. That role (`ansible/roles/grafana-cloud/alloy`) is fleet code applied by `grafana-agents.yml` to all desktops, servers and Pis. AD-10 says carve-outs are "each limited to cloud-configs/*" and the fleet is "unchanged", yet the epic modifies a fleet template and relabels every fleet series.
- This is also an observability contract change: existing dashboards, alert rules and recording rules are not mentioned.
- Fix: state in AD-10 that the alloy role is a shared role consumed by both contexts and that adding `environment` is a deliberate, fleet-wide, in-scope change (not a carve-out). Add a rule that shared roles under `ansible/roles` may only gain backward-compatible parameters when reused by cloud. Add an epics note to check dashboards and rules that key on label sets.

### H2. Moving the fantasy-hockey role out of `ansible/roles/raspi` breaks fleet artifacts not covered by AD-10

- `ansible/playbooks/raspi.yml:107` includes `../roles/raspi/fantasy-hockey`; `ansible/taskfile.yml:107` points the sanctioned vault-edit task at `roles/raspi/fantasy-hockey/defaults/main.yml`; `.github/dependabot.yml:35` watches `ansible/roles/raspi/fantasy-hockey/files`. The spec calls the move "the one move" but AD-10 does not say what happens to the raspi play, the vault task (AD-6 "one sanctioned edit path") or Dependabot.
- Also, E7 decommissions the Pi deployment only in the last-but-one epic, so between E3 and E7 either the fleet playbook is broken or the role is duplicated.
- AD-4 also lists local role dirs as `{common,grafana-cloud,media}`, but `raspi/` exists already, so the AD-4 text was stale before AD-10.
- Fix: add an explicit migration note to AD-10 (or the epics): the raspi play, vault task and dependabot entry are removed or repointed in the same change as the move; sequence Pi decommission with the move, or accept a copy until E7. Update AD-4's role list to include `raspi`.

### H3. AD-8 carve-out is mechanically contradicted by the repo's workflows and not bounded by trigger or authority

- `pipeline.yml` triggers on every path except a small ignore list, so a change under `cloud-configs/` runs the full lint, InSpec, molecule, docs and release pipeline and `cloud-deployment.yml` in parallel. The AD does not say whether the pipeline path-ignores `cloud-configs/**`, or whether release is gated on the cloud run.
- "never applies fleet playbooks" is only enforceable by convention: nothing stops `cloud-deployment.yml` from referencing `ansible/playbooks/*`. AD-8's "Prevents" and "Binds" lines still say CI never applies a playbook; the Binds list (`.github/workflows/*`) is fine, but the carve-out should be a testable rule.
- Fix: add to AD-10: (a) `cloud-deployment.yml` triggers only on `cloud-configs/digital-ocean/**` (and named shared-role paths, see M2), with `paths-ignore` in `pipeline.yml` decided explicitly; (b) it may only run playbooks located under `cloud-configs/`; (c) workflow lives in one file and has a `concurrency` group to serialize applies.

## Medium

### M1. State, stage and authority gaps in AD-10 are deferred to the spec, but the spec leaves them as open questions

- AD-1 says state "must be managed (location, backup, locking; see the state decisions in the cloud spec)". The spec only has: E1 local state, E5 "shared remote state with locking", Open Question "which backend (DO Spaces candidate)". Nothing is decided; the spine points at a decision that does not exist. Backup of the state is not mentioned anywhere (E8 backs up `fantasy-hockey.yml`, not state). Local state in E1 vs remote state in E5 also needs a migration step (`tofu init -migrate-state`) and a bootstrap problem: a Spaces bucket needs keys, which need a new secret (platform-decisions line 28 only conditionally lists it).
- Fix: record in AD-10 a decision or an explicit Deferred entry: backend = remote with locking from the first non-throwaway apply, state bucket created outside the state it holds (manual bootstrap per AD-2, with disposition), versioning on bucket as the backup, secrets for Spaces keys added to the AD-6 carve-out.
- Who may run apply: spec says localhost and CI "alternate"; AD-10 does not say whether local apply is permitted once CI exists. With a lock this is safe but undisciplined. Fix: state "CI is the default apply path; local apply is permitted and uses the same locked state" or restrict it to break-glass.
- Stage/environment model: the spec defines `stage` once and reuses it in tag, name, group and label, and says a test stage is a non-goal but "cheap later". AD-10 is silent. The spine's Deployment section still says "single environment" for the fleet. Fix: add one line in AD-10: stage is a single variable, `prod` is the only stage, and a second stage requires its own state key and tag, and its own CI approval; and an `environment` vs `stage` vocabulary definition (environment = fleet vs provider, stage = lifecycle).
- Label ownership: `environment`/`stage` labels are set by Alloy config in two places (fleet template, cloud role vars). No owner is named, so a future cloud role could define a conflicting label. Fix: name the alloy role owner and add the label names to Consistency Conventions.
- Dependabot: spec requires compose-image bumps to be applied automatically after merge (CAP-3, CAP-5). That means an auto-merged or one-click-merged Dependabot PR triggers a production apply with no test stage and no rollback. AD-10 says nothing. Also OpenTofu provider/version pins need a Dependabot ecosystem (`terraform`/`opentofu`) entry that does not yet exist. Fix: decide whether Dependabot PRs auto-merge (recommend: no, require a smoke test gate from E7 first) and add the ecosystem entries.
- Rollback: not decided anywhere. `prevent_destroy` guards volume and IP, but a bad compose image or role change has no revert path except git revert + re-run. Fix: Deferred entry: "rollback = git revert and re-run pipeline; no snapshot."

### M2. AD-4 "relative paths" reuse creates a hidden dependency from cloud to fleet

- Cloud playbooks reuse `ansible/roles/*` via `../../../..` relative paths. A change to `ansible/roles/grafana-cloud/alloy` or `common/*` for a Pi changes what the cloud pipeline would deploy, but those changes are outside the trigger path `cloud-configs/digital-ocean`. A fleet-role edit can silently break the next cloud apply, or never get applied until an unrelated cloud change.
- Fix: add the reused shared role paths to the `cloud-deployment.yml` trigger paths, or state the drift is accepted. Also name which roles may be reused (list in AD-10), so reuse stays a bounded surface; and note submodule floating (AD-7) means CI must init submodules at a fixed ref or accept floating.

### M3. AD-6 carve-out creates a second secret channel with an unenforced rule

- Spine now has: vault (shared password), GitHub org secrets (token, vault password, CI SSH key), and a local env var export. Rule "secrets consumed by cloud playbooks are still vault-encrypted" is fine, but the provider token is in the vault (via `bash-secrets.yml`, a fleet task that writes to `~/.bashrc` on desktops) AND in org secrets: two copies to rotate, and the E7 "token expiry" item has no home.
- `bash-secrets.yml` is a fleet file included by `desktop.yml`; adding `DIGITALOCEAN_TOKEN` there puts a cloud-provider-wide token in plaintext `.bashrc` on every desktop that runs it. That is fleet scope, so it is not "limited to cloud-configs". Also the CI SSH key and Spaces keys (if chosen) are not covered by the carve-out text.
- "Shares one vault password" widens the blast radius: the CI vault password (org secret) decrypts fleet secrets too. Fix: record this as an accepted risk, or use a separate cloud vault password.
- Fix: list the full secret inventory in AD-6's carve-out, add rotation owner, and say only the desktop playbook for the operator machine receives the export.

### M4. AD-9 carve-out: `docs/cloud` also needs a lint and a mirror rule decision

- "Organized by topic" is unconstrained; with `mkdocs.yml` nav, ls-lint, folderslint and lychee all touching the new tree, the spine does not say whether `docs/cloud/` is subject to the same filename and link rules (it should be). Also the Structural Seed does not list `cloud-configs/` or `docs/cloud/`.
- Fix: one sentence that `docs/cloud/*` follows all general docs conventions and needs one nav item per provider; add both to the Structural Seed.

## Low

- L1. AD-10 "Binds" includes `cloud-configs/taskfile.yml` and `.github/workflows/cloud-deployment.yml` but not the root `taskfile.yml` include (`cloud` prefix), `mkdocs.yml`, `.folderslintrc`, `.ls-lint.yml`, or devcontainer. These are shared fleet files edited by E1; list them as permitted touch points.
- L2. Consistency Conventions table names only `Ansible task names` and fleet host naming. Add cloud naming (`<stage>-<app>-...`), the `environment`/`stage` labels, and dynamic inventory groups (`ubuntu`, `fantasy-hockey`) so they are not reinvented.
- L3. AD-5 (per-machine exceptions) is not referenced: dynamic-inventory groups by tag are a fourth host-selection mechanism. State that AD-5 does not govern cloud inventories.
- L4. Capability map has no row for the new capability; add `CAP-*` pointer to the cloud spec and AD-10.
- L5. AD-2 bootstrap-step recording: the CI SSH key registration on DO, the Spaces bucket and org secrets are manual steps; each needs a disposition per AD-2.
- L6. Frontmatter `scope` and `binds` still say "whole Homelab Configs system" / FR-1..9; cloud work binds none of those FRs. Update `scope` and `binds` or `companions`.
- L7. `updated: 2026-10-10` is set, but status `final` with an added AD is worth a changelog line.

## Design paradigm and diagrams (question 4)

- Paradigm text: "Every node's configuration is declared once, per node role (desktop, server, raspi), in Ansible ... The declaration is the only source of truth; nothing else maintains a parallel record of node state." After AD-10 this is false for cloud resources (OpenTofu state is a second declaration and record) and cloud nodes have no node role or InSpec baseline, so "dual-verified" does not hold: they have Alloy only. Frontmatter `paradigm` still reads "declarative-convergence (Ansible-driven, dual-verified)".
    - Fix: amend the paradigm to "two bounded contexts: Fleet (declarative convergence, dual-verified) and Cloud (OpenTofu for resources, Ansible for software, single-verified by Alloy and synthetic check)", and state explicitly that cloud nodes have no InSpec baseline (is that intended? the spec's CAP list has no compliance item. Decide and record).
- First mermaid diagram: shows only fleet playbooks, roles, InSpec, Alloy. No OpenTofu, no `cloud-configs`, no GitHub Actions apply path, no DigitalOcean. It reads as the whole system.
- Second diagram: GH node text "never applies playbooks — see AD-8" is now wrong (cloud-deployment.yml applies). Operator is shown as the only applier; no droplet, no Spaces/state, no cloud arrow to Grafana Cloud. "Deployment & environment: single environment ... External providers: Grafana Cloud and GitHub" omits DigitalOcean and the second environment; it also contradicts AD-10's own cloud environment and the `environment` label.
- Fix: add a cloud subgraph to both diagrams, correct the GH label to "validates fleet; applies cloud only (AD-10)", and update the Deployment paragraph and Structural Seed.

## Answers to the four questions in brief

1. Leak: yes in three places: Alloy template label (H1), raspi role move with its playbook, vault task and dependabot entry (H2), `bash-secrets.yml` / vault password shared with fleet (M3). Everything else stays in `cloud-configs/*`.
2. Contradictions: AD-8 text ("never applies"; diagram label; pipeline path triggers) (H3); AD-6 title "Ansible Vault only" now has three channels (M3); AD-9 is consistent but unlinted (M4); AD-4 is consistent but creates a one-way hidden dependency (M2) and its role-dir list was already stale.
3. Gaps: state location/backup (undecided, M1), stage model (silent, M1), label ownership (silent, M1), who may run apply (silent, M1), Dependabot (silent, M1; also in conflict with E5 automation), rollback (silent, M1). None is marked Deferred in the spine.
4. Paradigm and diagrams: no longer accurate (see section above).
