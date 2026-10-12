# Epic 2 Context: Droplet via OpenTofu

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Create the production DigitalOcean droplet, a reserved IP and a 2 GB data volume with OpenTofu, managed locally from this repo, and wire the new `cloud-configs` area into the taskfile, linters and docs so it is checked like the rest of the repo. This is the foundation for the fantasy hockey app on DigitalOcean: later epics provision, deploy and observe what this epic creates. The volume and reserved IP must outlive droplet rebuilds so the URL and data persist.

## Stories

- Story 2.1: Devcontainer tools and DIGITALOCEAN_TOKEN delivery
- Story 2.2: cloud-configs scaffold with taskfile and linters
- Story 2.3: Docs skeleton for Cloud - Digital Ocean
- Story 2.4: OpenTofu droplet, SSH keys, tag and project
- Story 2.5: Reserved IP and 2 GB volume with prevent_destroy

## Requirements & Constraints

- Every step runs through go-task entry points and is covered by the repo's linters (folderslint, ls-lint, ansible-lint and an OpenTofu linter).
- Every story updates the docs under `docs/cloud/digital-ocean` in the same change.
- `DIGITALOCEAN_TOKEN` is delivered locally from `ansible/vars/vault.yml` through the `bash-secrets.yml` loop in `desktop.yml`. Token scopes: droplet, ssh_key, volume, reserved IP, project (firewall or domain only if needed). Document the scopes and manual steps.
- Droplet: one instance, `s-1vcpu-1gb`, region fra1, Ubuntu 26.04 LTS x64, public IPv4 plus reserved IP, name starting with `prod-fantasy-hockey`, tag `prod`, project `sommerfeld.io` named explicitly, DO improved monitoring on.
- Not allowed: DO firewall, user-data scripts, managed DB. Budget about $6 plus $0.20 per month.
- SSH keys: the existing DO key (from local `id_rsa.pub`) and the key named `picon___id_rsa.pub`.
- Volume: 2 GB, ext4 via `initial_filesystem_type`, attached at creation, mounted at `/mnt/<volume-name>`. Resizing is CPU/RAM only, never disk.
- Applying twice must plan no changes. Adding a second droplet should be a new map entry, with stage defined once.
- Destroy of the volume and reserved IP must be blocked by `prevent_destroy`.

## Technical Decisions

- Cloud deployments are a separate bounded context under `cloud-configs/<provider>/`, outside fleet node roles, inventory and the InSpec baseline. Layout: `cloud-configs/taskfile.yml` (included in the root taskfile with prefix `cloud`, tasks named `cloud:digital-ocean:*`), `cloud-configs/digital-ocean/opentofu` and `cloud-configs/digital-ocean/ansible`.
- OpenTofu declares cloud resources and its state records them. State stays local in this epic (remote backend comes in the GitHub Actions epic); the single local copy is a known accepted risk.
- `stage` is defined once in OpenTofu as the droplet tag and name (first value `prod`), and reaches Ansible only through the tag.
- OpenTofu is the sole owner of SSH key injection; adding a key later forces droplet replacement, which is accepted because the volume and reserved IP survive.
- Pinning (third-party): OpenTofu on the 1.12.x line with the exact version in `required_version`, the `digitalocean` provider pinned with its lock file committed, both set in Story 2.4.
- Operators may apply from localhost; the CI apply path comes later.
- Accepted risk: a Dependabot bump under `cloud-configs/` may replace the droplet.
- Devcontainer must provide `doctl` and `tofu`.
- Docs: organized by topic (not mirrored per playbook), MkDocs nav item "Cloud - Digital Ocean" with multiple pages, diagrams via kroki.io.
- Conventions: kebab-case filenames (ls-lint), folder structure via folderslint, conventional commits.

## Cross-Story Dependencies

- Story 2.1 (tools and token) is needed to run the apply in Stories 2.4 and 2.5.
- Story 2.2 (scaffold, taskfile, linters) provides the folders and task entry points that Stories 2.4 and 2.5 use.
- Story 2.3 (docs skeleton) gives every other story a place to document itself.
- Story 2.5 builds on the droplet from Story 2.4 (volume attachment and reserved IP assignment).
- Downstream: Epic 3 discovers the droplet by its tag via dynamic inventory and relies on the volume mount path; Epic 4 uses the reserved IP and volume data path and the droplet replacement drill; Epic 6 migrates state to a remote backend.
