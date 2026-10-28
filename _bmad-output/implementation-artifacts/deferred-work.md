- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`, `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Keep the exact OpenTofu pins in sync: the devcontainer feature `version`, the `lint-opentofu` image in `docker-compose.yml` and `required_version` in `configs-cloud/digital-ocean/opentofu/versions.tf` (plus the unpinned host install, see the Epic 2 retro action item 4).
  evidence: Only the compose image is bumped by Dependabot (there is no `devcontainers` ecosystem entry), and nothing bumps `required_version`; a devcontainer or host version other than 1.12.7 makes local `init`/`plan` fail on the version constraint, and no check catches it first. Raised again in the code review of Story 2.4.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-cloud-configs-scaffold-with-taskfile-and-linters.md`, `_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md`
  summary: Update `.github/copilot-instructions.md` (symlinked as `CLAUDE.md`) to mention `configs-cloud/`, the `task cloud:digital-ocean:*` tasks, the `opentofu` linter in the `task lint` list and that `task lint` runs `cloud:digital-ocean:opentofu:fmt` first.
  evidence: The Key Commands comment still lists the linters without `opentofu`; agent-instruction edits are out of scope for a build review fix.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-docs-skeleton-for-cloud-digital-ocean.md`
  summary: Drop the stale `export DIGITALOCEAN_TOKEN` line from existing `.bashrc` files via `bash-secrets.yml`, and make the write replace an existing export instead of appending a second line when the token is rotated (Epic 2 retro action item 3).
  evidence: The devcontainer half of this entry was fixed in `6f8671f`. `configs-homelab/ansible/tasks/bash-secrets.yml` still removes only `GITHUB_METRICS_EXPORTER_TOKEN` as obsolete, and its `lineinfile` has no `regexp`.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-5-reserved-ip-and-2-gb-volume-with-prevent-destroy.md`
  summary: Add a repeatable check that `prevent_destroy` on the volume and the reserved IP still refuses a destroy plan.
  evidence: Only a one-time manual `tofu plan -destroy` proved it; deleting a `lifecycle` block passes `fmt -check` and CI. Needs real state, so it belongs with the remote-state and CI work in Epic 6.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-5-reserved-ip-and-2-gb-volume-with-prevent-destroy.md`
  summary: Prove a droplet replacement with an already existing volume and reserved IP assignment (detach, re-attach, still mounted, IP re-assigned).
  evidence: Story 2.5 created the volume and the assignment in the same apply as the replacement; Story 4.3 is the planned drill.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-2-retro-item-4-bashrc-token-cleanup.md`
  summary: Add `no_log: true` to the secret-carrying tasks in `bash-secrets.yml` and to the `include_tasks` loop in `desktop.yml`.
  evidence: The token travels through `line`/`item`, which Ansible prints in task output and diffs; this predates the change.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-2-retro-item-4-bashrc-token-cleanup.md`
  summary: Add a Molecule scenario that seeds an old `.bashrc` export and asserts a rotated secret leaves one line and `DIGITALOCEAN_TOKEN` is gone.
  evidence: The behavior was verified only by a manual scratch run; no automated test covers `bash-secrets.yml`.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-1-dynamic-inventory-and-base-provision-yml.md`
  summary: Confirm the Docker apt repository supports the Ubuntu 26.04 codename when `provision` first runs on the droplet.
  evidence: The `docker` role uses `distribution_release` for the repo suite; unverified (maybe-false, medium). The first real provision run settles it.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-1-dynamic-inventory-and-base-provision-yml.md`
  summary: Add an automated check for the dynamic inventory groups, the droplet `tags` merge and the `changed=0` second run.
  evidence: Only static linters reach `configs-cloud`; a wrong `do_tags` key silently leaves the `ubuntu` or `fantasy-hockey` group empty. Needs a token or fixture, fits Story 6.1.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-2-swap-and-alloy-on-the-droplet-with-environment-and-stage-labels.md`
  summary: Add an automated check that renders the cloud Alloy template and the inventory stage/environment values, and asserts swap and the active config on the droplet.
  evidence: Only static validation covers the new roles; dropping `external_labels` or the `copy` task would keep every check green. Needs a Molecule or InSpec scenario for cloud nodes or a real droplet.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-2-swap-and-alloy-on-the-droplet-with-environment-and-stage-labels.md`
  summary: Bring `provision.yml` back under ansible-lint once vault-encrypted vars no longer block it.
  evidence: The playbook is in `exclude_paths` of `.ansible-lint.yml` because lint cannot decrypt `grafana-vault.yml`; same cause as the fleet playbooks tracked in issue #172.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-4-droplet-motd-with-banner-live-os-line-and-update-info.md`
  summary: Add an automated check that runs the MOTD scripts against stamp fixtures (0, 1, N updates) and asserts only the role's scripts and 98-reboot-required stay executable, idempotently.
  evidence: Nothing in the repo runs the motd role or its scripts; a changed grep pattern or a dropped exclude would keep every check green. Cloud roles have no Molecule/InSpec harness yet.

## Deferred from: code review of spec-3-3 and spec-3-4 (2026-10-13)

- No automated check runs the MOTD scripts against stamp fixtures or asserts exec bits and idempotence (same as the build-review entry above; needs a cloud-role Molecule/InSpec harness).
- MOTD layout and second-run idempotence not yet observed on the droplet (maybe-false, medium if broken): settled by running `task cloud:digital-ocean:ansible:provision` twice and `ssh root@<ip> 'run-parts --lsbsysinit /etc/update-motd.d | cat -A'`.

## Deferred from: build split of epic-3 retro items 9, 10 and 16 (2026-10-13)

- source_spec: none
  summary: Fix the Epic 3 docs drift in tasks-and-linters.md, droplet.md and provisioning.md (epic-3 retro item 9).
  evidence: The concrete drift is listed in finding 4 of `epic-3-retro-2026-10-13.md` (tree without roles/, provision row without MOTD, folderslint row, ansible-lint exclusion, droplet.md Tags row, provisioning.md role order and stray blank line); the collections sentence in provisioning.md was already updated by item 10. Split from a combined build of retro items 9, 10 and 16; independently shippable, scheduled right after item 10.

- source_spec: none
  summary: Add a lychee retry or accept rule for 429 and 5xx in the markdown link check (epic-3 retro item 16).
  evidence: Finding 17 of `epic-3-retro-2026-10-13.md`: the pre-commit link check failed on transient GitHub 502/503 and a docs.ansible.com 429, forcing commit retries. Split from a combined build of retro items 9, 10 and 16; independently shippable, scheduled after item 9.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-10-pin-provisioning-collections.md`
  summary: Decide who bumps the Ansible Galaxy pins in `configs-cloud/digital-ocean/ansible/requirements.yml` and how (Renovate `ansible-galaxy` manager or a manual check per epic).
  evidence: Dependabot has no Galaxy ecosystem and the repo has no Renovate config, so `community.digitalocean 1.27.0` and `community.general 13.5.0` never get update PRs.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-10-pin-provisioning-collections.md`
  summary: Add a check that `provision.yml` resolves only against the collections installed from `requirements.yml`, so a new role using an unpinned collection (e.g. `community.docker`, `community.crypto`) fails loudly.
  evidence: The pin list was built by hand from a grep; the devcontainer already has `community.docker` and `ansible.posix` installed, so an unpinned use would silently work. Fits the cloud test-harness story (epic-3 retro item 15).

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-items-9-11-16-deploy-wait-docs-drift-link-retries.md`
  summary: Wait for the first-boot apt lock (apt-daily, unattended-upgrades) before the Docker role's apt tasks on a new droplet.
  evidence: maybe-false, medium if true. The wait play covers cloud-init only, and the apt module waits 60 s (default `lock_timeout`). Settled by the Story 4.3 replacement drill: watch for "Could not get lock" on a fresh droplet.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-items-9-11-16-deploy-wait-docs-drift-link-retries.md`
  summary: Move the wait play into a vault-free playbook (imported by `provision.yml`) so ansible-lint and `--syntax-check` can cover it in CI.
  evidence: `provision.yml` is in `exclude_paths` and its syntax check needs the vault password, so the new play (including the `hostvars` assert) was only checked by hand. Fits the cloud test-harness story (epic-3 retro item 15).

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-12-reconcile-idempotence-statement.md`
  summary: When epic-3 retro item 8 (stop fleet-only side effects) is built, remove the four-Alloy-task exception from `epic-3-context.md`, the Story 3.1 criterion in the epics file and `SPEC.md` CAP-2, and the matching sentence in `docs/cloud/digital-ocean/provisioning.md`.
  evidence: All four now say the exception lasts "until" item 8 lands, but item 8's action text in `sprint-status.yaml` does not mention restoring the plain "a second run changes nothing" statement, so it would go stale.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-12-reconcile-idempotence-statement.md`
  summary: Add `changed_when: false` to the read-only `docker version` and `docker compose version` tasks in `ansible-roles-collection/docker/tasks/ubuntu/40-info.yml`, then drop the Docker exception from `epic-3-context.md`, the Story 3.1 criterion, `SPEC.md` CAP-2 and `docs/cloud/digital-ocean/provisioning.md`.
  evidence: The second provision run on 2026-10-13 (epic-3 retro item 13) ended `changed=6`: the four expected Alloy tasks plus `Docker  ----  Setup  ----  Verify Docker installation` and `Verify Docker Compose installation`, both plain `command` tasks without `changed_when`. The fix belongs to the submodule repo (AD-8).

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-3-retro-item-8-alloy-config-template-and-fleet-extras.md`
  summary: Add a Molecule scenario for the fleet `grafana-cloud/alloy` role with its apartment defaults (token file, capabilities and override capability lines present, one restart on a config change, none on a second converge).
  evidence: No test runs this role (`configs-homelab/tests/molecule` has only `common` and `omarchy`); Story 3.5 covers only the `alloy_fleet_extras: false` branch with the cloud template. A dropped `notify` or a mis-rendered `{% if %}` in the override would reach every apartment node unnoticed. Needs a systemd container and Grafana APT access.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-5-molecule-tests-for-the-cloud-ansible-roles.md`
  summary: The cloud `swap` role has no automated test; only a second provision run on the droplet checks it.
  evidence: Story 3.5 dropped the `swap` scenario by human decision on 2026-10-13. `swapon` needs a privileged container, and every run of a privileged systemd test container hung up the host's desktop session on `/dev/tty1` (root cause from Grafana Cloud logs, see the addendum in `epic-3-retro-2026-10-13.md`). A test would need a safe way to run `mkswap`/`swapon` (e.g. a disposable VM) without touching the host.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-5-molecule-tests-for-the-cloud-ansible-roles.md`
  summary: The Story 3.5 criterion in `epics-fantasy-hockey-digitalocean.md` still says "Given a pull request / When `pipeline.yml` runs", but `pipeline.yml` has no `pull_request` trigger; reword it to a push.
  evidence: `docs/pipelines.md` states `pipeline.yml` has no `pull_request` trigger and only runs on `push` (branches except `dependabot/**`) and the Tuesday schedule. The wording predates Story 3.5 (blind review finding).

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Add a test, or at least a `--check` dry run, for the pi4-0002 fantasy hockey cleanup play and its container guard.
  evidence: `raspi.yml` is excluded from ansible-lint and no test touches the play; Docker cannot run in the unprivileged Molecule containers. The play deletes data without a backup and runs for the first time on the real Pi.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Automate the check of the fantasy-hockey role's compose part (start, restart on a config change, running asserts).
  evidence: The Molecule scenario runs only the file tasks because unprivileged containers cannot run Docker; a broken register name or restart condition is only found on the droplet.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Tighten the modes of the fantasy hockey data folder and data file (0750/0640) so player emails are not readable by other local users.
  evidence: The data folder is 0755 and the seeded file 0644, carried over from the Pi role; the file lists every player's email. The app rewrites the file by atomic rename, so the file mode also depends on the app's umask.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Verify that `deploy-fantasy-hockey.yml` resolves `default_user` to `fantasy-hockey` (not `root` from `vars/main.yml`), for example with a vault-free play variant or an inventory fixture.
  evidence: The Molecule scenario sets `default_user` in `test-vars.yml` and never runs the playbook; adding `vars_files: [../vars/main.yml]` would make the stack run as root with CI green.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Confirm `python3-requests` is on the droplet (needed by `community.docker.docker_container_info`), or install it in `provision.yml`.
  evidence: Unverified (maybe-false, medium if missing). Settle with `dpkg -s python3-requests` on the droplet; cloud-init usually depends on it.

- source_spec: `_bmad-output/implementation-artifacts/spec-4-1-move-fantasy-hockey-role-and-deploy-fantasy-hockey-yml-with-nginx.md`
  summary: Set `diff: false` (or `no_log`) on the fantasy-hockey `.env` and data-file template tasks so `--diff` runs do not print secrets and player emails.
  evidence: The template tasks in `roles/fantasy-hockey/tasks/files.yml` print the full rendered content with `--diff`; carried over unchanged from the Pi role.

- source_spec: `_bmad-output/implementation-artifacts/epic-4-retro-2026-10-14.md`
  summary: Add a files-only Molecule check for the fleet role `grafana-cloud/exporters` (the `.env` with `CADVISOR_BIND_ADDRESS` for the default and the cloud override, and the port spec in the compose file).
  evidence: Epic 4 retro D7. The role gained a `.env` and a bind assert, runs on every homelab node and the droplet, and no test runs it.

- source_spec: `_bmad-output/implementation-artifacts/epic-4-retro-2026-10-14.md`
  summary: Test the volume tasks of `deploy-fantasy-hockey.yml` (derived device and mount path, fact refresh) and drop the second source of the mount path (role default versus play var).
  evidence: Epic 4 retro D8. The mount, fact refresh and derived path feed the role's mount guard, were only proven by the Story 4.3 drill, and the role default `/mnt/prod_fantasy_hockey_data` duplicates the play-derived path.

- source_spec: `_bmad-output/implementation-artifacts/epic-4-retro-2026-10-14.md`
  summary: Let cAdvisor see mounts made after it started (`/:/rootfs:ro,rslave`), or restart it after the deploy mounts the volume.
  evidence: Epic 4 retro D9. On a replacement droplet provision starts cAdvisor before the deploy mounts the volume, so the volume's file system metrics are missing until cAdvisor restarts.

- source_spec: `_bmad-output/implementation-artifacts/epic-4-retro-2026-10-14.md`
  summary: Set or check the UID of the `fantasy-hockey` deploy user so it stays 1000, the image user that owns the data folder.
  evidence: Epic 4 retro D12. It matches only because it is the first user on the droplet; the Molecule image has `ubuntu` as UID 1000, so the test checks a different relation.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-4-retro-items-18-22-docker-mount-order-cadvisor-assert-docs-drift.md`
  summary: Add an automated check that runs the cAdvisor bind-address assert in `provision.yml` for an unset variable, `0.0.0.0` and `127.0.0.1`.
  evidence: The assert was verified only by a one-off local run; no Molecule scenario, lint rule or CI job runs `provision.yml`, so a weakened guard (for example a `default('127.0.0.1')`) would ship unnoticed and a lost override would publish cAdvisor on the droplet's public IP.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-1-grafana-dashboard-for-the-droplet-and-the-app.md`
  summary: Add a lint check that the Grafana manifests under `grafana-cloud/manifests/git-sync/apps/` parse and that every query carries `environment="digital-ocean"`.
  evidence: Only ls-lint and folderslint touch `git-sync/`; a Git Sync write-back or edit dropping the label filter would mix homelab series into the droplet dashboard without any check failing.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-1-grafana-dashboard-for-the-droplet-and-the-app.md`
  summary: Assert in the cloud `alloy` Molecule verify that the job names (`integrations/node_exporter`, `integrations/docker`, `integrations/cadvisor`, `fantasy-hockey`) and the cAdvisor keep-list entries the droplet dashboard queries are present.
  evidence: `alloy/verify.yml` checks only the external labels; renaming a job or trimming the keep rule of `prometheus.relabel "integrations_cadvisor"` in `config.alloy.j2` would empty dashboard panels with CI green.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-1-grafana-dashboard-for-the-droplet-and-the-app.md`
  summary: Reconcile `grafana-cloud/manifests/git-sync/README.md` ("do not manually edit") with the practice of hand-writing new dashboards there that Git Sync then reconciles.
  evidence: `c7aca03`, the FRITZ!Box dashboards and Story 5.1 hand-write manifests in `git-sync/`, while the README calls the folder read-only; the rule is the user's to change.

## Deferred from: code review of spec-5-1-grafana-dashboard-for-the-droplet-and-the-app (2026-10-15)

- No lint or CI check reads the git-sync manifests (parse, `environment` filter) — same as the Story 5.1 entry above.
- The cloud Alloy Molecule verify does not pin the job names and the cAdvisor keep-list the droplet dashboard queries — same as the Story 5.1 entry above.
- `epic-5-context.md` says the dashboard reaches Grafana Cloud "not via manual UI edits", while Git Sync writes UI edits back into the manifest (documented in `monitoring.md`); reconcile together with the `git-sync/README.md` entry above.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-2-caddy-with-automatic-tls-replaces-nginx.md`
  summary: Automated test for the fantasy-hockey compose orchestration (remove_orphans freeing port 80, restart on Caddyfile change, container asserts) and the playbook's domain derivation and metadata read.
  evidence: Story 7.2 verification-gap review; Molecule cannot run Docker without a privileged container, so these run only in the operator's droplet deploy.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-7-retro-item-24-reconcile-epic-7-docs-with-the-as-built.md`
  summary: Add a Molecule case for the fantasy-hockey DNS guard where the domain resolves to the reserved IP plus a second address, and assert that it fails.
  evidence: Story 7.2's triage made the guard an equality check (`tasks/dns.yml`), but `tests/molecule/fantasy-hockey/molecule/default/verify.yml` only tests one wrong address, so the second-address rule is untested. Not caused by item 24, which changed only the message and the docs.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-3-caddy-logs-and-certificate-status-on-the-droplet-dashboard.md`
  summary: No automated `caddy validate` runs on the rendered Caddyfile; Molecule only text-matches it, so a Caddyfile Caddy rejects (outage) or that stops masking IPs passes lint and Molecule.
  evidence: Pre-existing since Story 7.2 (no Caddyfile linter in docker-compose.yml, taskfile.yml or pipeline.yml); Story 5.3's global log block raises the stakes. Fix is a `lint-caddyfile` service on `caddy:2.11.7` wired into `task lint` and the pipeline linter matrix.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-3-caddy-logs-and-certificate-status-on-the-droplet-dashboard.md`
  summary: The `loki.process "caddy"` log_type mapping and the Caddy-only `stream` rule have no repeatable behavioral test; reordering stages or dropping `stage.labels` keeps Molecule and `alloy validate` green while emptying the Proxy row.
  evidence: Only a one-off manual `loki.source.file` -> `loki.echo` run proves the labels (spec Implementation Notes); turning it into a lint service with fixture lines and a label diff needs a new Docker-based harness.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-3-caddy-logs-and-certificate-status-on-the-droplet-dashboard.md`
  summary: Unverified (medium if true): query strings in Caddy's `request.uri` may carry tokens or e-mail addresses (password reset or confirmation links) into Grafana Cloud Loki.
  evidence: Settle by checking whether sommerfeld-io/fantasy-hockey puts secrets or personal data in GET query strings; if so, filter `request>uri` with Caddy's `query` filter.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-3-caddy-logs-and-certificate-status-on-the-droplet-dashboard.md`
  summary: Unverified (medium if true): Top Paths `sum by (path)` over `[$__range]` may exceed Grafana Cloud Loki's series limit when scanners hit many distinct paths over long ranges.
  evidence: Settle by running the panel query over 7d and 30d in Explore after a few weeks of traffic; if it errors, reduce paths to their first segment or exclude 404s.

- source_spec: `_bmad-output/implementation-artifacts/spec-8-1-digitalocean-dns-zone-do-sommerfeld-app-in-opentofu.md`
  summary: The DNS record derivation, the four preconditions and the CAA issuer set in `dns.tf` (and the stage precondition in `droplets.tf`) have no repeatable plan-level test; a broken key template or a dropped precondition passes `fmt -check` and `tofu validate` (Story 6.1).
  evidence: `tofu validate` now runs in `task lint` (`63fabb4`, `6da3d31`) and in the `validate-opentofu` CI job (`3e90479`, `a96b137`), but validate does not evaluate preconditions or `for_each` keys against the `droplets` map; no `.tftest.hcl` exists. Fix: a `tofu test` with `mock_provider`, run in `task lint` and CI. Now Story 6.1's first acceptance criterion; delete this entry when Story 6.1 is done.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-8-retro-item-35-opentofu-lint-without-init.md`
  summary: Make CI run the `task cloud:digital-ocean:opentofu:validate` and `task grafana-cloud:validate` entry points (fresh checkout, lock file unchanged) instead of an inlined copy of their commands.
  evidence: `validate-opentofu` (`.github/workflows/pipeline.yml`) inlines `init`/`validate`; no workflow runs `task lint` or the validate tasks, so dropping the init or `-lockfile=readonly` from a task passes CI. Fits retro item 36.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-8-retro-item-35-opentofu-lint-without-init.md`
  summary: OpenTofu does not enforce the exact `required_version` pin locally, so the pin strategy (Epic 2 retro item 5) and `api-token.md` rely on a check that does not happen.
  evidence: host `tofu 1.12.7` ran `init -backend=false`, `validate` and `plan` with exit 0 on a root pinning `1.99.0` (2026-10-22); only CI ties the version to the pin by deriving the image tag. Deciding on a guard reverses the item 5 "no sync check" decision.

- source_spec: `_bmad-output/implementation-artifacts/spec-9-1-enable-the-wi-fi-collector-in-the-homelab-alloy-config.md`
  summary: Nothing automated guards the Wi-Fi collector: a misspelled or dropped `enable_collectors = ["wifi"]` in the fleet Alloy template, or one added to the DigitalOcean template, passes `task lint` and CI.
  evidence: `alloy validate` v1.16.0 and v1.21.0 exit 0 for `enable_collectors = ["wifix"]`, and `alloy run` skips the unknown name without an error (2026-10-23); no Molecule scenario renders the fleet template (the cloud `alloy` scenario renders the cloud template only and does not assert the collector's absence). Fix: a lint check (or Alloy role scenario) that asserts the collector in the fleet template and its absence in the cloud template. Fits Epic 6 (CI checks). Now a Story 6.1 acceptance criterion (Epic 9 retro item 44); delete this entry when Story 6.1 is done.

- source_spec: `_bmad-output/implementation-artifacts/spec-9-2-wi-fi-dashboard-in-the-git-sync-folder-network.md`
  summary: No `task lint` or CI step reads the Git Sync manifests: a JSON parse error, a duplicate `metadata.name` across dashboards, or more than 20 Git Sync resources reaches `main` green.
  evidence: Only ls-lint touches `grafana-cloud/manifests/git-sync/` (filenames). `6813c9f` put two dashboards with `metadata.name` `000000013` (`fritz-box-status.json`, `network-fritz-box-status.json`) on `feat/epic-9` and every check passed (Story 9.2 review, verification-gap layer). Fix: a `jq` check in `task lint` and CI for parse, unique `metadata.name` and count <= 20. Same gap as the Story 5.1 triage row 1; fits Epic 6. Now a Story 6.1 acceptance criterion (Epic 9 retro item 44); delete this entry when Story 6.1 is done.

- source_spec: `_bmad-output/implementation-artifacts/spec-9-2-wi-fi-dashboard-in-the-git-sync-folder-network.md`
  summary: `grafana-cloud/manifests/git-sync/README.md` forbids manual edits, while hand-written dashboards (5.1, 9.2) are the established way to add one; nobody owns re-committing what Git Sync writes back after the first sync.
  evidence: Story 9.2 review (blind hunter) and Story 5.1 triage row 12; the README rule is the user's, so changing it is their decision.

## Deferred from: code review of spec-9-1 and spec-9-2 (2026-10-23)

- source_spec: `_bmad-output/implementation-artifacts/spec-9-2-wi-fi-dashboard-in-the-git-sync-folder-network.md`
  summary: The cloud `alloy` Molecule verify does not assert that the rendered cloud config has no `wifi` collector, so copying the line into the cloud template passes `molecule-cloud`.
  evidence: `configs-cloud/digital-ocean/tests/molecule/alloy/molecule/default/verify.yml` asserts labels, `'github' not in alloy_config` and `'remotecfg' not in alloy_config` only. A one-line assert fixes it, but Epic 9 forbids any change under `configs-cloud/`; do it with the fleet guard in Epic 6. Now a Story 6.1 acceptance criterion (Epic 9 retro item 44); delete this entry when Story 6.1 is done.
- source_spec: `_bmad-output/implementation-artifacts/spec-9-1-enable-the-wi-fi-collector-in-the-homelab-alloy-config.md`
  summary: The fleet Wi-Fi collector line and the Git Sync manifests (parse, unique `metadata.name`, count <= 20) still have no standing check; both are already logged above and fit Epic 6.
  evidence: Code review 2026-10-23, verification-gap layer; same entries as the Story 9.1 and 9.2 deferrals. Now a Story 6.1 acceptance criterion (Epic 9 retro item 44); delete this entry when Story 6.1 is done.

## Deferred from: spec-epic-8-retro-item-37-fix-epic-8-docs-and-guard-drift (2026-10-28)

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-8-retro-item-37-fix-epic-8-docs-and-guard-drift.md`
  summary: Older DNS docs next to the item 37 fixes still use state-based or stale commands: `dns-zone.md` Troubleshooting > NXDOMAIN compares with `tofu output dns_records`, "Import an Existing Zone or Record" uses a bare `doctl compute domain records list` without the R4 key rules, and `docs/pipelines.md` names `task cloud:digital-ocean:{init,fmt,plan,apply}` while the tasks are `cloud:digital-ocean:opentofu:*`.
  evidence: Blind-hunter review of item 37 (2026-10-28); `task --list-all` shows only `cloud:digital-ocean:opentofu:plan` and `:validate`. Not caused by item 37, which fixed only the R6-R11 locations.

## Deferred from: spec-epic-8-retro-item-36-harden-the-validate-opentofu-ci-job (2026-10-28)

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-8-retro-item-36-harden-the-validate-opentofu-ci-job.md`
  summary: OpenTofu formatting still uses hand-kept root lists (`task lint` calls `cloud:digital-ocean:opentofu:fmt` and `grafana-cloud:fmt`; `lint-opentofu` runs `fmt -check -recursive configs-cloud grafana-cloud`), so a root outside those trees is validated but never formatted or fmt-checked.
  evidence: Blind-hunter review of item 36 (2026-10-28); item 36 (R2) covered the validate lists only. Fix: drive fmt from `.github/workflows/assets/find-opentofu-roots.sh` too, or run `fmt -recursive` from the repository root.
- source_spec: `_bmad-output/implementation-artifacts/spec-epic-8-retro-item-36-harden-the-validate-opentofu-ci-job.md`
  summary: The `lint-opentofu` image (`ghcr.io/opentofu/opentofu:1.13.2` in `docker-compose.yml`) no longer matches `required_version = "1.12.8"`, while `docs/cloud/digital-ocean/api-token.md` says the pin matches that image.
  evidence: Blind-hunter review of item 36 (2026-10-28); predates item 36. Decide whether the linter follows the pin or the devcontainer, then fix the image or the doc.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-8-retro-item-38-reconcile-runbook-m13-and-the-epic-8-ac.md`
  summary: Check whether a single `+norec` query to `ns5`/`ns6.kasserver.com` can hit an instance that has not yet received the NS records, so that runbook M13 passes while another instance still serves the A record with `aa`.
  evidence: Unverified, would be medium. all-inkl quotes 3 to 4 hours for changes to take effect; M13 now gates M14 on the referral without a wait. Settled by whether the KAS nameservers are anycast with independently updated zone copies, and whether NS additions and the A deletion reach each instance in order (repeated queries over time after a test change).
