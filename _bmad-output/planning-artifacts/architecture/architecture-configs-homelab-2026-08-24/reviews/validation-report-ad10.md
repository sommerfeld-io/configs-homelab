# Validation report: AD-10 architecture amendment

Folded from four independent reviews (rubric, adversarial, version-verify, cloud-seams) of ARCHITECTURE-SPINE.md after the AD-10 amendment. Date: 2026-10-10.

## Gate verdict

AD-10 is the right boundary, but the spine is not ready to gate cloud story execution until the state, CI-secret, apply-path and label decisions are made and the stale sections are brought in line.

Reviewers: R = rubric, A = adversarial, V = version-verify, C = cloud-seams. Actions are recommendations only: autofix, discuss, defer, ignore.

## Summary

| ID    | Tier       | Finding                                               | Raised by  | Action  |
|-------|------------|-------------------------------------------------------|------------|---------|
| F1    | Critical   | Cloud state is mandated but undecided                 | R, A, C, V | discuss |
| F2    | Critical   | Secrets in CI widen the fleet vault blast radius      | R, A, C    | discuss |
| F3    | Critical   | Apply path is open and AD-8 has no enforcement        | R, A, C    | discuss |
| F4    | High       | Spine sections are stale after AD-10                  | R, C, A    | autofix |
| F5    | High       | Moving the fantasy-hockey role breaks fleet artifacts | A, C, R    | discuss |
| F6    | High       | Label and stage contract has no owner                 | A, C, R    | discuss |
| F7    | High       | SSH key ownership has two owners                      | A, R       | discuss |
| F8    | High       | Cloud reuses fleet roles with no consumption contract | A, C       | discuss |
| T1-T9 | Medium/Low | See tail                                              | various    | mixed   |

## Critical and high findings

### F1 Cloud state is mandated but undecided (Critical)

- **Raised by:** R, A, C, V
- **Spine location:** AD-10 AD-1 carve-out; Deferred (missing)
- **Problem:** The spine points at 'state decisions in the cloud spec' that do not exist (backend is an open question). No backup, encryption, access scope, bucket credentials or local-to-remote migration. E1 would create prevent_destroy resources on unbacked-up laptop state. Spaces lock support is unconfirmed (V).
- **Suggested action (discuss):** Decide the backend and make remote, versioned, private state a precondition for the first real resources; otherwise list it in Deferred with an owner.

### F2 Secrets in CI widen the fleet vault blast radius (Critical)

- **Raised by:** R, A, C
- **Spine location:** AD-6 carve-out; AD-10 AD-6 bullet
- **Problem:** One shared vault password in an org-level secret lets any org workflow decrypt fleet vault.yml and grafana-vault.yml. DIGITALOCEAN_TOKEN has two owners (vault via bash-secrets.yml, and the org secret) with no rotation rule. CI SSH key and Spaces keys are not covered. bash-secrets.yml is a fleet file, so the carve-out leaks. AD-6 'out of scope' for CI secrets contradicts the carve-out.
- **Suggested action (discuss):** Choose a separate cloud vault and password, or record shared-password as an accepted risk. List the full secret inventory, scope org secrets to this repo and a protected environment, name a rotation owner.

### F3 Apply path is open and AD-8 has no enforcement (Critical)

- **Raised by:** R, A, C
- **Spine location:** AD-10 AD-8 bullet; AD-8; .github/workflows/pipeline.yml
- **Problem:** No single mutation path: laptop and CI can both apply, the state lock does not serialize Ansible, and a Dependabot bump (image slug, compose image) can replace the droplet unattended. No trigger paths, concurrency group, or plan-then-apply gate. 'Never applies fleet playbooks' is discipline-only. pipeline.yml runs on all pushes except ignored paths, so cloud changes also run the full fleet pipeline. AD-8 as written ('never apply and verify against a containerized target') is already contradicted by the existing molecule job.
- **Suggested action (discuss):** Add a single-apply-path clause: CI on main, plan on PRs, concurrency group, approval when plan contains replace or destroy, local apply break-glass only. Decide the pipeline.yml paths-ignore. Rewording AD-8 to match the molecule job is an autofix.

### F4 Spine sections are stale after AD-10 (High)

- **Raised by:** R, C, A
- **Spine location:** Frontmatter; Design Paradigm; both diagrams; Deployment and environment; Structural Seed; Capability map; Stack; AD-4 role list
- **Problem:** Paradigm says dual-verified, single source of truth, single environment, providers Grafana and GitHub only. Diagram says GitHub never applies playbooks. No cloud-configs or docs/cloud in the seed, no cloud rows in the capability map, no OpenTofu stack rows, scope and binds omit the cloud spec. AD-4 role list omits raspi (stale before AD-10). Cloud nodes are Alloy-only verified, not InSpec.
- **Suggested action (autofix):** Rewrite as two contexts (Fleet, Cloud), add diagram nodes, seed paths, map rows and stack rows with verified versions. Whether cloud nodes get an InSpec baseline is a decision (discuss).

### F5 Moving the fantasy-hockey role breaks fleet artifacts (High)

- **Raised by:** A, C, R
- **Spine location:** AD-10 AD-4 bullet; AD-4
- **Problem:** ansible/playbooks/raspi.yml:107, ansible/taskfile.yml:105-107 (sanctioned vault edit task) and .github/dependabot.yml:35 reference the old path. Until E7 either raspi.yml breaks or the role is duplicated with two data files. The raspi_ to fantasy_hockey_ rename touches fleet-owned vars. No data-migration story; seed-only-when-absent silently starts with template data.
- **Suggested action (discuss):** Specify the cutover: move, raspi.yml, taskfile and Dependabot entry change in one commit; add a data-migration step before the move is done.

### F6 Label and stage contract has no owner (High)

- **Raised by:** A, C, R
- **Spine location:** AD-10 (silent); Consistency Conventions
- **Problem:** environment and stage labels are set in two places (fleet Alloy template and cloud vars); story edits to the same template can clobber each other. 'Stage defined once' is impossible across OpenTofu and Ansible without a named bridge. Values drift (digital-ocean, digitalocean). Adding environment=homelab is a fleet-wide change AD-10 calls 'unchanged', and may affect dashboards and alert rules.
- **Suggested action (discuss):** New AD for the label contract: fleet owns the template, cloud only sets variables, stage travels as an OpenTofu tag consumed via dynamic inventory. State the homelab Alloy change as sanctioned.

### F7 SSH key ownership has two owners (High)

- **Raised by:** A, R
- **Spine location:** AD-10 (silent); AD-6 carve-out
- **Problem:** Droplet ssh_keys is ForceNew, so adding the CI key later replaces the droplet; adding it through Ansible authorized_key means CI cannot bootstrap. A droplet created from a laptop lacks the CI key.
- **Suggested action (discuss):** OpenTofu owns key injection from the first apply, including the CI key; Ansible never adds authorized keys. Record the manual DO registration under AD-2.

### F8 Cloud reuses fleet roles with no consumption contract (High)

- **Raised by:** A, C
- **Spine location:** AD-10 AD-4 bullet
- **Problem:** Relative-path reuse makes a one-way hidden dependency. Fleet changes to a reused role are outside cloud-deployment.yml triggers, so breakage surfaces at an unrelated later apply. Fleet vars and hosts.yml values (prompt, default_user) are unavailable to droplets.
- **Suggested action (discuss):** List which roles may be reused, only via documented variables; pass shared values in cloud group_vars; add a path filter or an accepted-drift note plus a --check smoke test.

## Medium and low findings (tail)

| ID | Tier   | Finding                                                                                                                                                                                  | Raised by | Spine location                       | Action  |
|----|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------------------------------------|---------|
| T1 | Medium | AD-7 pinning does not bind cloud-configs (OpenTofu, provider lock file, collection, linter, Dependabot ecosystem); ansible-lint row labels the image version 0.79.33 as the tool version | R, C, V   | AD-7; Stack                          | autofix |
| T2 | Medium | Port 8080 and /metrics are public until E6; bind to loopback and expose only 80 and 443 from the first deploy                                                                            | A         | AD-10 (silent)                       | discuss |
| T3 | Medium | Operational envelope thin: backup and restore of fantasy-hockey.yml, unattended patching, rollback (git revert and re-run), cost guardrail, DR depends on F1                             | R, C      | AD-10; Deferred                      | defer   |
| T4 | Low    | AD-10 tagged ADOPTED although nothing is built; status final without changelog line; open verifications not recorded                                                                     | R, C      | AD-10 heading; frontmatter           | autofix |
| T5 | Low    | AD-9 carve-out has no page set or owner; docs/cloud must follow ls-lint, folderslint, lychee and one nav item                                                                            | R, A, C   | AD-9; AD-10                          | autofix |
| T6 | Low    | AD-2 closed list omits cloud manual steps (DO key registration, Spaces bucket, org secrets); each needs a disposition                                                                    | A, C      | AD-2                                 | autofix |
| T7 | Low    | Replacement droplet briefly shares tags with the old one; derive groups from stage and app tags and use serial: 1                                                                        | A         | AD-10 inventory clause               | defer   |
| T8 | Low    | Binds omits shared touch points (root taskfile include, mkdocs.yml, .ls-lint.yml, .folderslintrc); AD-5 does not govern cloud inventories; cloud naming missing from conventions         | C, R      | AD-10 Binds; Consistency Conventions | autofix |
| T9 | Low    | Docker apt repo support for Ubuntu 26.04 (resolute) and exact OpenTofu and provider latest versions not confirmed; slug ubuntu-26-04-x64 confirmed                                       | V         | Stack (missing)                      | defer   |

## What must change in the spine

- **State:** Name the backend or defer it with an owner. Require remote, versioned, private state before real resources. Say who may apply (F1, F3).
- **Secrets in CI:** One cloud-secrets rule: inventory (token, vault password, SSH key, state credentials), scoped org secrets plus protected environment, rotation owner, separate or explicitly shared vault. Fix the AD-6 'out of scope' wording (F2).
- **Label contract:** New AD: label names and values in one fleet-owned place, stage travels by tag, homelab Alloy change declared sanctioned (F6).
- **Apply path and AD-8 enforcement:** CI on main is the apply path, plan on PRs, concurrency group, approval on replace or destroy, trigger paths, pipeline.yml paths-ignore decision. Reword AD-8 so roles-in-containers (molecule) is allowed and applying playbooks to live targets is the prohibition (F3, F5, F8).
- **Stale sections:** Frontmatter, paradigm, both diagrams, deployment paragraph, seed, capability map, stack, AD-4 role list, AD-10 tag (F4, T4, T8).
- **Pinning:** Extend AD-7 to cloud-configs and fix the ansible-lint label (T1).

## What changes in the cloud spec and stories

- **DIGITALOCEAN_TOKEN versus the inventory plugin:** The community.digitalocean plugin documents DO_API_TOKEN and others, not DIGITALOCEAN_TOKEN. Set oauth_token from an env lookup or export both, and add tags to attributes so filters and keyed_groups work. Test the claim 'needs only DIGITALOCEAN_TOKEN'.
- **Volume mount fallback:** DO auto-mounts only at volume creation and gives no fixed /mnt/name rule; OpenTofu only formats. Plan an Ansible mount with fstab nofail and verify across a reboot; prefer volume_ids on the droplet.
- **Spaces locking unconfirmed:** No DO source for use_lockfile on Spaces and no DynamoDB fallback. Test concurrent locks before E5 commits, or choose another backend.
- **Synthetic monitoring limits:** The 100k free executions figure is third-party. One 1-minute check from three probes is about 130k per month; set probes and frequency, and count existing checks.
- **SSH key ForceNew ordering:** Decide the CI key in the droplet story before the first apply, since adding it later replaces the droplet (F7).
- **Remote state before real resources:** Move the remote-state story ahead of any apply that creates prevent_destroy resources, or run E1 on throwaway resources only (F1).
- **Also touch:** Bind 8080 to loopback from the first deploy (T2); add a data-migration step before the role move is done (F5); merge or order the two Alloy label stories (F6).

## Facts verified against the repo

- ansible/playbooks/raspi.yml:107, ansible/taskfile.yml:105-107 and .github/dependabot.yml:35 reference the fantasy-hockey role path that moving the role would break.
- pipeline.yml runs on all pushes except ignored paths.
- The existing molecule job in pipeline.yml applies roles to containers, which already contradicts AD-8 as written.
