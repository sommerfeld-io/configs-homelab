# Rubric review: ARCHITECTURE-SPINE.md after AD-10 amendment

Reviewer: independent rubric walker. Inputs: the spine, `spec-fantasy-hockey-digitalocean/SPEC.md`, `spec-configs-homelab/SPEC.md`. No files other than this one were modified. Tech versions for OpenTofu, `community.digitalocean`, Caddy and the Ubuntu 26.04 slug were not web-verified (the spine does not name them; see F-8).

## Verdict

AD-10 is a sound, well-scoped bounded-context decision and the carve-outs keep the fleet rules intact, but the spine is internally inconsistent after the amendment (the unamended sections still describe a fleet-only, single-environment, never-applies world) and the cloud state, CI-secret and environment decisions are pointed at rather than made.

## Findings

### F-1 (high) OpenTofu state is mandated "managed" but no decision exists to point at

- **Location:** AD-10, carve-out AD-1 bullet ("the state must be managed (location, backup, locking; see the state decisions in the cloud spec)").
- **Problem:** the cloud SPEC contains no state decisions. Its Open Questions list "Which remote state backend with locking for E5 (DO Spaces is the candidate)?" as unresolved. The spine therefore delegates to a non-existent decision. Backend choice, who holds the backend credentials (a second secret: Spaces keys), state backup and recovery, state encryption (state holds the droplet and volume IDs and may hold secrets), and the local-versus-CI alternation (CAP-5 "localhost and the workflow can alternate runs") are all divergence points for the epics level. "Backup" is named but nothing says what is backed up, where, or how a lost or corrupted state is recovered (`tofu import` runbook). Also, CAP-1 (E1) runs on local state before E5 exists, so a migration step from local to remote state is an undecided hand-off.
- **Fix:** add to AD-10 an explicit state sub-rule: one remote backend with locking, named (or listed in Deferred with an owner and "decide before E1 completes / before E5"), state versioning enabled on the bucket as the backup, backend credentials class (org-level secret, same as the token), no state committed to git, and the local-to-remote migration is part of E5. If not decided, move it to Deferred with the explicit wording that E1 may only use local state and must not be run against production resources until the backend exists.

### F-2 (high) Unamended sections now contradict AD-10 and omit the cloud context

- **Location:** frontmatter (`scope`, `binds`, `sources`, `companions: []`); Design Paradigm text and mermaid; "Deployment & environment" paragraph and its mermaid ("GitHub ... never applies playbooks — see AD-8"); Structural Seed; Capability → Architecture Map; Stack; Consistency Conventions.
- **Problem:**
    - "Deployment & environment" still says "single environment — the live homelab fleet itself ... no separate dev/staging tier. External providers: Grafana Cloud and GitHub". The cloud context introduces DigitalOcean as a provider and a `stage` dimension (`prod`, a possible test stage). The envelope section is the one the altitude owns and it is now wrong.
    - The diagram label "never applies playbooks" is false under the AD-8 carve-out.
    - The Structural Seed has no `cloud-configs/`, `docs/cloud/`, or `.github/workflows/cloud-deployment.yml`. The same code-structure question the spine exists to answer is unanswered for the new tree (`cloud-configs/<provider>/{tofu,ansible}` layout is not stated).
    - The Capability map has no rows for the cloud SPEC's CAP-1..11, and `binds` lists only the fleet FRs. The cloud spec is not listed in `companions`/`sources`. The cloud SPEC names this spine as a companion, but the reverse link is missing.
    - Stack lists no OpenTofu, `opentofu` provider (`digitalocean/digitalocean`), `community.digitalocean`, `doctl`, Caddy or the OpenTofu linter, although the cloud SPEC constrains "Pin OpenTofu and provider versions".
    - Design Paradigm claims "Every node's configuration is declared once ... in Ansible" and "only source of truth", reconciled only by the AD-1 carve-out, not stated at the paradigm level.
- **Fix:** update scope/binds/companions, add a "Cloud" paragraph and diagram node to Deployment & environment (stages, provider, GitHub Actions applies cloud only), add the cloud tree to Structural Seed, add Capability-map rows (cloud CAP-1..11 to AD-10 plus AD-1/6/7), and add stack rows with pinned versions (verified current at edit time).

### F-3 (high) Secrets in CI: blast radius and the SSH key are not decided

- **Location:** AD-10 carve-out AD-6 bullet; AD-6 "Out of scope" clause.
- **Problem:**
    - The carve-out puts the shared vault password (one password for all vaults, including the fleet's `vault.yml`) into an org-level GitHub secret reachable from `cloud-deployment.yml`. That widens the exposure of the fleet vault to any workflow or fork-PR/Dependabot path in the org that can read org secrets. The spine does not restrict secret scope (selected repositories, environment-scoped secrets, no `pull_request_target`, protected branch only).
    - The cloud SPEC introduces a CI-only SSH keypair ("private key never leaves CI") and it is not covered anywhere in AD-6 or AD-10. Its lifecycle (generation, registration on DigitalOcean, rotation) is a divergence point.
    - The spec says the token is exported locally from `vault.yml` via `bash-secrets.yml`, while CI uses a separate secret: two sources for one token with no rotation rule (rotate both). Also the state backend credentials (F-1) are unplaced.
    - Contradiction risk: AD-6 says CI secrets are "out of scope" and "already adequate", while the carve-out then governs them. Readers will not know which applies.
- **Fix:** rewrite as one cloud-secrets rule: enumerate the CI secrets (provider token, vault password, SSH private key, state-backend credentials), require repository/environment-scoped org secrets with a GitHub Environment (`prod`) and no exposure to untrusted PR code, and a rotation rule. Consider a cloud-only vault with its own password (or document explicitly that sharing the fleet password is an accepted, bounded risk, mirroring how the homelab spec accepts the vault/sudo password risk). Adjust AD-6's "out of scope" wording to point to AD-10 rather than contradict it.

### F-4 (medium) AD-8 carve-out has no enforcement and no apply-safety envelope

- **Location:** AD-10 carve-out AD-8 bullet; AD-8 carve-out sentence.
- **Problem:** "never applies fleet playbooks" is discipline-only (the existing spine style marks such gaps as Deferred enforcement notes, but this one is not). Nothing constrains triggers: path filter `cloud-configs/digital-ocean/**` is in the SPEC, not the spine; no concurrency group (needed to protect state locking against two runs); no gate between Dependabot bump and applying to production (CAP-5 auto-applies Dependabot bumps with no approval); no apply-versus-plan distinction on PRs. A droplet-replacing change (CAP-8) reached by an image-slug bump auto-merge would cause outage.
- **Fix:** add to AD-10: apply runs only on the default branch after merge, a single concurrency group per provider/stage, `plan` (read-only) on PRs, and `prevent_destroy` on the volume and reserved IP (already in CAP-1; reference it). Add an enforcement note: workflow targets only `cloud-configs/**` playbooks and the fleet playbook list is never referenced (cheap grep/lint candidate), or list as Deferred.

### F-5 (medium) Stage/multi-droplet structure and shared labels are an open divergence point

- **Location:** AD-10 Rule ("one folder per provider"); Consistency Conventions; Deferred.
- **Problem:** the cloud SPEC non-goals say a second droplet (test stage or another app) must be "cheap later", yet the rule fixes only a provider-level folder. How a second stage or app is added (new folder, workspace, variable, module) is undecided, so two later units can diverge. The cross-cutting naming conventions (droplet name `prod-fantasy-hockey…`, tag, `stage` single definition, `environment` label) live only in the SPEC and platform-decisions. `environment=homelab` must also be added to the existing fleet Alloy role, which is an AD-4/AD-1 fleet change that the spine does not mention (the "unchanged" claim in AD-10 is therefore not strictly true).
- **Fix:** add a row to Consistency Conventions for cloud naming (`<stage>-<app>` name, `stage` defined once and reused in tag/name/inventory group/label, label keys `environment` and `stage`), and state that the fleet `grafana-cloud/alloy` role gains the `environment` label as the single sanctioned fleet-side change. Add a one-line decision or Deferred item for how a second stage/app is added.

### F-6 (medium) AD-7 pinning does not bind the new dependencies

- **Location:** AD-7 "Binds"; Deferred.
- **Problem:** the cloud SPEC requires pinned OpenTofu and provider versions and an OpenTofu linter, and uses the `community.digitalocean` collection, `doctl`, container images (Dependabot-driven compose bumps), and Caddy. AD-7 binds only InSpec, the submodule and CI tool images, so the rule that prevents "third party silently changing behavior" has no coverage for the new tree. The `.terraform.lock.hcl` commit decision and the Ansible collection pinning (`requirements.yml`) are undecided. Dependabot auto-apply (F-4) makes this more critical.
- **Fix:** extend AD-7 Binds to `cloud-configs/**` (OpenTofu version, provider lock file committed, `community.digitalocean` pinned in requirements, linter image pinned) or add a Deferred item with owner.

### F-7 (medium) Operational envelope for the cloud context is thin

- **Location:** AD-10 (absent); Deferred.
- **Problem:** the altitude owns operations. Not decided, deferred or marked open: data backup and restore of `fantasy-hockey.yml` (CAP-11) versus the spine and fleet spec's "no formal backup tooling" (the cloud spec reconciles this in Assumptions, the spine does not); unattended patching (spec Open Question on moving unattended-upgrades earlier); monitoring/alert ownership for the droplet (CAP-4 is "observe first", no alerts) while AD-1's "dual verification" paradigm says InSpec + Alloy and InSpec does not cover the droplet (AD-10 says it is outside the InSpec baseline) so the "dual-verified" claim silently becomes single-verified for cloud; cost guardrail ($6/mo budget); Pi decommission (the fantasy-hockey role leaves `ansible/roles/raspi`, a fleet change); disaster recovery ("replacement droplet comes up from the repo alone" depends on F-1 and backup).
- **Fix:** add a short "Cloud operations" note to AD-10 or Deferred entries: verification is Alloy-only plus post-deploy smoke test (state it, so the paradigm text is not contradicted), backup deferred to E8 with the explicit rule from the SPEC constraint (seed only when absent, overwrite only from backup), unattended-upgrades timing open.

### F-8 (low) Technology claims unverified, AD-10 tagged `[ADOPTED]`

- **Location:** AD-10 heading; frontmatter `status: final`, `updated`.
- **Problem:** `[ADOPTED]` elsewhere means ratifying existing brownfield behavior. AD-10 is a new, not-yet-built decision (the repo's `cloud-configs/` does not exist, per the SPEC it is epics E1..E8 still pending), so the tag overstates its state and is the only non-ratified AD. The spine remains `status: final` after a substantive amendment without a changelog or re-review note. Open verifications in the SPEC (Ubuntu 26.04 slug, `community.digitalocean` inventory options, volume auto-mount) affect AD-10's wording on "dynamic inventory (by tag)" and "reused through relative paths, not `roles_path`" and are not recorded as assumptions in the spine. Relative-path role reuse is also not lintable-verified (the SPEC itself asks if ansible-lint passes).
- **Fix:** tag AD-10 `[PROPOSED]` (or `[NEW]`) until E1 lands, add the open verification items to Deferred, and note the amendment in frontmatter.

### F-9 (low) Minor internal wording issues

- AD-10 carve-out AD-4 says "Roles in `ansible/roles` are reused through relative paths, not `roles_path`", but AD-4's role group list `{common,grafana-cloud,media}` does not mention `raspi`, from which the fantasy-hockey role moves; the Structural Seed also omits `raspi` and `server`-role directories, so the "one move" cannot be located from the spine.
- AD-10 Binds lists `cloud-configs/taskfile.yml`, which is inside `cloud-configs/*`; the root taskfile include (prefix `cloud`) and the Consistency Conventions naming for `cloud:digital-ocean:*` task names are not mentioned in the conventions table.
- AD-9 carve-out ("organized by topic") gives no enforcement or minimal page set; the SPEC requires a "Cloud - Digital Ocean" nav item and kroki diagrams.

## Checklist summary

| Check                                            | Result                                                                     |
|--------------------------------------------------|----------------------------------------------------------------------------|
| Fixes real divergence points, misses none        | Partial: state, CI secrets, stage structure, labels missing (F-1, F-3, F-5) |
| Each Rule enforceable and prevents its divergence | Partial: AD-8 carve-out and AD-4 relative-path rule discipline-only (F-4)   |
| Deferred cannot let units diverge                | Fail for cloud: state backend is neither Deferred nor decided (F-1)         |
| Named tech verified-current                      | Not applicable to cloud (nothing named), existing stack unchanged (F-6)     |
| Ratifies brownfield, no contradiction            | Partial: unamended sections contradict AD-8 carve-out (F-2, F-8)            |
| Covers both specs                                | Fleet spec yes; cloud spec CAPs absent from the map (F-2)                   |
| Operational/environmental envelope               | Fail for cloud: environments, state backup, CI secrets, ops (F-1, F-2, F-3, F-7) |
