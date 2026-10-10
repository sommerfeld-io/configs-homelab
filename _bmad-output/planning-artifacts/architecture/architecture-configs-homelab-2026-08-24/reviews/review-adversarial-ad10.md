# Adversarial review: AD-10 and rewritten AD-1

Scope: ARCHITECTURE-SPINE.md (updated 2026-10-10) against `spec-fantasy-hockey-digitalocean` (SPEC.md, epics.md, platform-decisions.md, stories.yaml, .memlog.md). Method: pairs of stories that each satisfy every AD literally and still do not compose.

Verdict: AD-10 sets the boundary (what may be exempt) but defines no interfaces across it, so the two-layer design (OpenTofu, then Ansible, reusing fleet roles, vars and secrets) has four ownerless shared entities (label and stage scheme, state and apply path, secrets and SSH keys, the moved role plus shared fleet roles) and several stories can pass every AD yet fail to build together.

## Tier 1: blocking, close before story execution

### H1. Stage and label scheme have no single owner (stories 4, 6, 7, 8)

Pair:

- Story 4 satisfies "stage is defined once" as an OpenTofu local that feeds tag `prod` and the droplet name `prod-fantasy-hockey...`.
- Story 7 satisfies "labels `environment=digitalocean`, `stage=prod`" by adding Alloy role vars with a literal default `stage: prod`, or by deriving it from an inventory group.
- Story 8 independently adds a hardcoded `environment=homelab` to `config.alloy.j2`.

Why each is AD-compliant:

- AD-10's AD-1 carve-out forbids Ansible from reading the state file, so the stage cannot travel from OpenTofu to Ansible except through the tag.
- No AD says the tag is the contract.
- AD-4 says nothing about who may edit a fleet role for a cloud need.

Why they clash:

- "Defined once" is physically impossible across two toolchains without a named bridge.
- Value drift: the folder is `digital-ocean`, the label is `digitalocean`, and the inventory group is `fantasy-hockey` (hyphen, and Ansible warns on hyphenated group names).
- Homelab series get `environment` but no `stage`, so dashboards and queries must tolerate a missing label.
- Story 7 edits the fleet template (`ansible/roles/grafana-cloud/alloy`) while story 8 edits the same file. They will conflict, or story 8 will clobber a templated variable that story 7 introduced.
- Neither story says where the `source` label comes from.

Fix: new AD-11 (observability label contract):

- A canonical table of label names and allowed values (`environment`: `homelab`|`digitalocean`; `stage`: `prod`|`test`, with `stage` absent or `none` on homelab) lives in one file, e.g. the grafana-cloud alloy README.
- That README is the only owner of the Alloy template and its label vars, and it is a fleet-owned artifact. Cloud consumes it only by setting variables, never by editing the template.
- Stage originates as a tag, set in OpenTofu, and is consumed by Ansible only through the dynamic inventory (tag to group to var). Delete "defined once" in favor of "defined once per layer, derived across the boundary through the tag".
- Merge stories 7 and 8, or order 8 first.

### H2. Two mutation paths for OpenTofu and for the droplet, with state stranded (stories 5, 11, 15, 16)

Pair:

- Story 5 creates real resources, including `prevent_destroy` ones, with local state on the operator's laptop (E1 "local state").
- Story 15 introduces remote state, and story 16 makes CI apply on every merge.

Why each is AD-compliant:

- AD-10 says state "must be managed (location, backup, locking)" but does not say when, nor which path (local or CI) is allowed to apply.
- Story 5 is allowed to run first because the spec orders it so.

Why they clash:

- Between stories 5 and 15 there is unbacked-up local state for resources that cannot be destroyed. Story 11's replacement drill also runs before 15.
- After 16, a laptop `tofu apply` and a CI apply both mutate. The state lock serializes tofu but not Ansible, so a local `deploy-services` can race a CI deploy on the droplet (the Dependabot bump scenario).
- CI has no gate: any change under `cloud-configs/digital-ocean` (a compose image bump) runs `tofu apply`, and a provider default drift or an image-slug change replaces the droplet unattended.
- Where the migrated state's backend config lives is unspecified. If the backend block is committed with partial config, the first local run after story 15 may re-init against the wrong backend.

Fix: tighten AD-10 with a "single mutation path" clause:

- After the remote backend exists (which should be the precondition for story 5's real resources, i.e. move story 15 ahead of 5 or make 5 use the remote backend), CI on `main` is the only apply path.
- Local apply is break-glass and must use the same backend.
- CI uses a workflow `concurrency:` group, plan then apply, with a protected GitHub environment approval required whenever the plan contains `replace` or `destroy`.
- Local state, if used at all, is throwaway and may not hold `prevent_destroy` resources.

### H3. SSH key ownership: tofu `ssh_keys` vs CI key vs authorized_keys (stories 4, 16)

Pair:

- Story 4 sets `ssh_keys` on the droplet to the two existing DO keys.
- Story 16 registers the CI public key "manually" on DigitalOcean and runs CI against the existing droplet.

Why each is AD-compliant:

- Each follows the story text.
- AD-2 requires a documented disposition for manual steps; story 16 documents one.

Why they clash:

- The CI key can only reach the droplet if it is in `ssh_keys` (ForceNew in the DO provider, which means replacement) or is added via Ansible `authorized_key`. These are two owners of one entity.
- Adding it to tofu `ssh_keys` later destroys the droplet. Adding it via Ansible means CI cannot bootstrap the first provision.
- A droplet created from a laptop (stories 4 and 5) holds only operator keys, so the first CI run cannot connect.

Fix: AD-10 clause "access ownership": OpenTofu owns the set of keys injected at creation (including the CI key as a `digitalocean_ssh_key` resource or data source from the start, before story 4 ships), and Ansible must never add further authorized keys. The manual DO registration step is recorded under AD-2 with a "tracked to close" disposition. Move the CI-key decision into story 4.

### H4. One vault password in an org-level secret = fleet secrets exposed to the cloud pipeline (AD-6 carve-out)

Pair:

- Story 16 stores the vault password as an org-level secret (as AD-10 and the spec prescribe).
- Story 7 uses `grafana-vault.yml` (the fleet vault) for the Alloy token on the droplet, so CI decrypts it.

Why each is AD-compliant:

- AD-6 carve-out explicitly allows this and says "share the one vault password".

Why they clash:

- Every org repo ("so other repos can deploy to DO") and any workflow in this repo can now decrypt `vault.yml`, which holds fleet secrets (sudo, tokens, etc.).
- AD-8's "never applies fleet playbooks" is a claim about playbooks, not about fleet secrets in CI memory. The spine thus has a hole between AD-6 and AD-8.
- `DIGITALOCEAN_TOKEN` has two owners, `vault.yml` (local) and the org secret (CI), with no rotation or sync rule. Story 15's Spaces keys fit neither (they are consumed before Ansible, but the carve-out lists only the token and the vault password), so the story author must invent a home.
- Story 16's CI key's private half is also org-wide: any org repo can reach the droplet.

Fix: tighten the AD-6 carve-out: cloud has its own vault file (`cloud-configs/<provider>/ansible/vars/vault.yml`) and its own password, or at minimum a secret-classification table (pre-Ansible secrets: DO token, Spaces keys, which live only in GitHub secrets and are mirrored into the local vault by an explicit documented rotation task; post-Ansible secrets: vault only). Scope org secrets to selected repositories and a protected environment. Give the Alloy token for the droplet its own, limited-scope Grafana token.

## Tier 2: serious, will cause rework

### H5. The shared fleet roles and vars are an unmanaged API (stories 6, 7, 9)

Pair:

- Story 7 "reuses the existing grafana-cloud role" and story 6 reuses roles from `ansible/roles` through relative paths.
- A fleet story changes a role default, a group var in `ansible/hosts.yml`, `ansible/vars/main.yml` or `ansible/vars/ubuntu.yml`, or the `config.alloy.j2` role logic.

Why each is AD-compliant:

- AD-10 says fleet rules "apply unchanged", and only roles are covered by the relative-path carve-out.

Why they clash:

- Droplet hosts are not in the fleet inventory, so any role that reads fleet group_vars or `vars/*.yml` (default_user, the ubuntu prompt "same as ubuntu server in hosts.yml", Alloy settings) gets nothing, or gets different values.
- The bash prompt is defined in `ansible/hosts.yml`, which cloud cannot import.
- AD-8 and AD-10 forbid a CI check that applies fleet roles, so a fleet change that breaks the droplet is found only when the next cloud change merges.
- Nothing says which side owns the vars or who runs the check when a fleet role changes.

Fix: new AD (cloud consumption contract): cloud may reuse only roles, and only through their documented defaults and README-listed variables. Vars, tasks and inventory data are not reusable across the boundary. Any shared value (prompt, default_user) is passed explicitly in `cloud-configs/<provider>/ansible/group_vars`. A fleet change to a reused role must run a cloud `--syntax-check` and `--check` (AD-8 permits it) and a path filter on `ansible/roles/**` must trigger the cloud workflow (or an explicit decision that it does not).

### H6. The moved role leaves two owners and a broken Pi path until E7 (stories 9, 10)

Pair:

- Story 9 uses `git mv` of the role from `ansible/roles/raspi/fantasy-hockey` to cloud.
- `ansible/playbooks/raspi.yml`, `ansible/taskfile.yml` and `.github/dependabot.yml` (directory `ansible/roles/raspi/fantasy-hockey/files`) still reference it, and the Pi runs it until E7.

Why each is AD-compliant:

- AD-10 explicitly permits "the one move".

Why they clash:

- Between stories 9 and the E7 decommission, `raspi.yml` either breaks (missing role) or the role is copied (two owners, and an app that runs at both Pi and DO against two data files).
- Story 10 repoints Dependabot, so the Pi compose stops receiving bumps.
- `raspi_` to `fantasy_hockey_` var renames require editing `ansible/vars/raspi.yml`, which is fleet-owned.
- No story migrates the data file from the Pi to the volume, and story 9's seed rule ("seed only when absent") means a fresh droplet starts with the default template and silently discards real league data unless the operator restores it by hand.
- Both Pi and DO would also compete for the same public scoreboard identity until DNS or IP cutover (E6/E7).

Fix: AD-4 carve-out must state the cutover sequence: the move and the Pi's removal from `raspi.yml` happen in the same change, with the role's Pi task list (and its Pi-only compose targets) removed or explicitly frozen. Add an explicit data-migration story before story 9's `done_checkpoint`. Dependabot config and `ansible/taskfile.yml` entries move in the same change.

### H7. Hidden dependency: Alloy scrape targets, and the synthetic check, assume 8080 is public (stories 7, 9, 13; CAP-9)

Pair:

- Story 7 scrapes `:8080/metrics` from Alloy (local, so fine).
- Platform-decisions says "app listens on 8080, open to the internet" and there is no DO firewall.
- Story 13 probes the public URL.

Why they clash:

- The app's `/metrics` endpoint is world-readable until E6 binds 127.0.0.1, and nothing in the AD set forbids exposing it. The spec only defers the issue.
- E6 changes the binding, which in turn breaks any Alloy scrape that targets the public IP, and breaks any synthetic check built on `:8080`.

Fix: AD clause on cloud exposure: only 80/443 are public. Alloy scrapes via loopback or docker network from day one, and the compose file binds 8080 to 127.0.0.1 from story 9 (not E6).

## Tier 3: gaps and inconsistencies

### H8. Dynamic inventory vs tag filtering must not collide with the stage tag (story 6, CAP-8)

The inventory selects by tag with groups composed from tags. `prod` as a tag and `fantasy-hockey` as an app tag are both "tags". A replacement droplet (story 11) lives briefly with the same tags as the old one, so `provision.yml` against `ubuntu` hits both hosts in the window. Nothing says tags must include a droplet-generation or a state filter. Fix: AD-10 inventory clause: groups are derived from exactly `stage` and `app` tags; plays run with `serial: 1` and never target a host without the full tag set.

### H9. Docs rule: "organized by topic" has no enforcement (AD-9 carve-out)

AD-9 says each playbook has exactly one doc, but now `cloud-configs/*/ansible/playbooks` are exempt and the CI lint "markdown-links" cannot flag a missing page. The spec also requires docs "in every epic", but the carve-out names no minimum page set, so two stories can each create `docs/cloud/digital-ocean/index.md`. Fix: name the page list in AD-10 (what runs where, how it works, how to run, manual setup) and one owner (story 3).

### H10. AD-8 versus the existing molecule CI job

AD-8 says this repo's CI never applies and verifies a playbook against a containerized target, but `.github/workflows/pipeline.yml` has a `molecule` job doing exactly that (`task molecule:test:<scenario>`). CLAUDE.md documents this. The spine misstates reality, so the "carve-out only for cloud" reading is false and any future story can cite molecule as precedent for fleet apply in CI. Fix: reconcile AD-8's wording with the molecule job (roles-only in containers is allowed; playbook apply against a live target is the real prohibition).

### H11. AD-2 versus the "manual setup" docs for cloud

Manual DO setup, org secrets and SSH key registration are listed as doc content but are not run through AD-2's "disposition" requirement, because AD-2 lists a closed set of fleet bootstrap steps. Fix: extend AD-2's list or declare that cloud manual steps follow the same disposition rule.

### H12. State sensitivity

OpenTofu state contains droplet and volume metadata and may include sensitive values. AD-1 requires managing "location, backup, locking", not encryption, access scope, or retention, and the Spaces bucket would use keys that the vault rule does not cover (see H4). Fix: add to AD-10 "state is private, versioned, encrypted at rest, and the bucket credentials are not reused for anything else".

## Suggested new or tightened ADs, summary

| Hole | Action                                                                                          |
|------|-------------------------------------------------------------------------------------------------|
| H1   | New AD-11 observability label contract; fleet owns the template; stage crosses via tag only     |
| H2   | AD-10: single apply path (CI on main), remote state before real resources, plan gate            |
| H3   | AD-10: OpenTofu owns SSH key injection; Ansible never adds authorized keys                      |
| H4   | AD-6 carve-out: separate cloud vault or secret classification; scoped org secrets               |
| H5   | New AD: cloud consumes fleet roles only via documented variables; path-filtered smoke check     |
| H6   | AD-4 carve-out: atomic move plus Pi cutover plus data migration                                 |
| H7   | AD-10: only 80/443 public; bind app to loopback from first deploy                               |
| H8   | AD-10 inventory clause: groups from `stage` and `app` tags; `serial: 1`                         |
| H9   | AD-9 carve-out: name the page set and owner                                                     |
| H10  | Reword AD-8 to match the molecule job                                                           |
| H11  | Extend AD-2 to cloud manual steps                                                               |
| H12  | AD-10 state hygiene (encryption, access, versioning)                                            |
