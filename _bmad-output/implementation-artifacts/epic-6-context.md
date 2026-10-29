# Epic 6 Context: GitHub Actions

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Changes under `configs-cloud/digital-ocean` are applied by a GitHub Actions workflow (`cloud-deployment.yml`) against shared, locked OpenTofu state, so deployment is decoupled from app releases and localhost and CI can alternate runs without corrupting state. Before that, the epic closes the cloud half of the Epic 9 Wi-Fi collector deferral with one Molecule assert. Epic 6 runs last in this breakdown, after Epics 7, 8 and 9. Story 6.1 was re-scoped on 2026-10-28 by user decision to that single assert.

## Stories

- Story 6.1: Molecule check that the cloud Alloy config has no Wi-Fi collector
- Story 6.2: Remote state with locking
- Story 6.3: cloud-deployment.yml with org secrets and CI SSH key

## Requirements & Constraints

- Merging a change (including a Dependabot bump) under `configs-cloud/digital-ocean` runs `cloud-deployment.yml` through static checks, OpenTofu, provisioning and deployment, using only org-level secrets and shared locked state.
- Every step runs locally and in CI through the same go-task entry points, checked by the repo's linters.
- The droplet's rendered Alloy config must never enable the `wifi` collector; the cloud `alloy` scenario must fail if one is added to `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`.
- Already in place, do not re-add: `tofu fmt -check` and `tofu validate` for every OpenTofu root (CI lint matrix, `validate-opentofu` job, `task lint`), and ansible-lint in the CI lint matrix.
- Out of scope (user decision 2026-10-28): `tofu test` with `mock_provider`, a vault-free `ansible-playbook --syntax-check` with collection pin check (to be tested later against real infrastructure, InSpec is the candidate), a fleet-template `wifi` lint check, `alloy validate` changes, a Git Sync manifest check, and a dynamic inventory `do_tags` check.
- Two concurrent runs must be blocked by the state lock; local and CI must see the same state after migration, and the backend and its backup must be documented.
- Manual setup (org secrets, CI key registration on DigitalOcean) is documented under `docs/cloud/digital-ocean` in the same change, like every story in this breakdown.
- Still in force: no DO firewall, no user-data scripts, no managed DB, one droplet, budget about $6.20 per month.

## Technical Decisions

- **Single CI apply path:** `cloud-deployment.yml` runs only on `main`, is serialized by a concurrency group so runs cannot overlap on the state lock, and applies only OpenTofu and playbooks under `configs-cloud/`. It never applies fleet playbooks. Operators may still apply from localhost.
- **Secrets in CI:** the DigitalOcean token, the shared vault password and the CI SSH private key are organization-level GitHub secrets (OpenTofu runs before Ansible and cannot read the vault). Backend credentials (Spaces keys, if Spaces is chosen) are separate secrets of the same kind. All vaults share one password; exposing it as an org secret is accepted because the operator is the only org member.
- **Locally**, `DIGITALOCEAN_ACCESS_TOKEN` is exported from the vault key `DIGITALOCEAN_TOKEN` via `configs-homelab/ansible/tasks/bash-secrets.yml`; the vault password is prompted.
- **Remote state:** the backend and its locking support are open; DO Spaces is the candidate with unconfirmed locking. State records cloud infrastructure only; software stays declared in Ansible. A state backup mechanism is required.
- **Spaces cost (open user decision):** DO Spaces is a flat $5 per month (250 GiB included; $0.02/GiB applies only above that), which nearly doubles the budget of about $6.20 per month for a state of a few KB. Before choosing the backend, the user decides whether to pay for Spaces or use a free-tier S3-compatible store (for example Cloudflare R2 or Backblaze B2, which adds a second provider account and keys); the decision is recorded in the story and the backend docs.
- **CI SSH key:** a fresh CI-only keypair whose private key never leaves CI. OpenTofu is the sole owner of SSH key injection, so adding the CI public key replaces the droplet once; this is accepted because the volume, reserved IP and DNS record (pointing at the reserved IP) survive replacement, and TLS certificates live on the volume.
- **Inventory:** Ansible discovers the droplet through the `community.digitalocean` dynamic inventory by tag, with the token passed explicitly via `oauth_token`; no static inventory.
- **Pinning:** OpenTofu, the provider (with lock file) and Ansible collections are pinned. A Dependabot bump may replace the droplet; accepted risk.
- **Molecule rules:** cloud scenarios use unprivileged containers, no systemd as PID 1, no host mounts. The cloud `alloy` verify already asserts labels and the absence of `github` and `remotecfg`; the Wi-Fi assert follows that pattern.

## Cross-Story Dependencies

- Story 6.1 is independent of 6.2 and 6.3. When done, delete the `deferred-work.md` entries for the `tofu test` plan-level tests (spec-8-1), the cloud `alloy` Molecule assert, and the combined fleet line and Git Sync note; the fleet-template Wi-Fi check and the Git Sync manifest check stay deferred in their own entries.
- Story 6.2 must precede 6.3: CI needs shared, locked state before it can apply OpenTofu.
- A deferred repeatable check that `prevent_destroy` on the volume and reserved IP still refuses a destroy plan needs real state and was earmarked for the remote-state and CI work in this epic.
- Story 6.3 depends on manual setup outside the repo (org-level GitHub secrets, registering the CI public key on DigitalOcean); these steps are documented, not automated.
- The later hardening epic (post-deploy smoke test against the domain) and backup epic (state and app data backup) build on this epic.
