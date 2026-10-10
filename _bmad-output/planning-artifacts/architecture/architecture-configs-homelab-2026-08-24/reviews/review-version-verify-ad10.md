# Review: version and claim verification for AD-10 and the cloud spec

Date: 2026-10-10. Scope: ARCHITECTURE-SPINE.md (AD-1..AD-10), SPEC.md and platform-decisions.md of spec-fantasy-hockey-digitalocean. Method: web search and fetches of primary docs where reachable; secondary sources are marked.

## Verdict

The committed technologies are real and current, but three claims rest on unverified or contradicted assumptions: Spaces lock support, the `DIGITALOCEAN_TOKEN` env var for the inventory plugin, and automatic volume mounting.

## Claim table

| Claim | Source | Status |
|-------|--------|--------|
| OpenTofu is current and pin-able (1.12.x line) | eosl.date lists 1.12.4 as latest (1.11, 1.10 still supported; 1.9 EOL 2026-05-14); Wikipedia 1.12.3 (2026-06-18). Secondary sources, official releases page not fetched | confirmed (exact latest unconfirmed) |
| digitalocean provider exists and is maintained | releases.hashicorp.com index top entry 2.95.0, undated snapshot | confirmed (latest version unconfirmed; pin by reading the registry at implementation time) |
| OpenTofu S3 backend supports native locking via `use_lockfile` (conditional writes, If-None-Match) | opentofu.org S3 backend docs; third-party says needs 1.10+ | confirmed |
| DO Spaces works as S3 backend for OpenTofu | OpenTofu docs list skip_* flags and endpoints for S3-compatible stores; no DO doc found | unconfirmed |
| DO Spaces supports `use_lockfile` (If-None-Match conditional writes) | No DigitalOcean source found. OpenTofu's 1.10 announcement warns not all S3-compatible stores support it. DynamoDB fallback is impossible on Spaces | unconfirmed (highest-risk claim: "shared locked state", E5) |
| Droplet attached volume with `initial_filesystem_type = ext4` is auto-mounted under `/mnt/<name>` and persists | DO volume docs: auto format and mount exists, but only "at creation" of the volume; mount point not stated (examples use `/mnt/volume-<region>-NN`); fstab persistence not stated | unconfirmed. Partly doubtful: a volume created standalone and attached by `digitalocean_volume_attachment` is documented as NOT auto-mounted. Needs a live test or an Ansible mount/fstab task fallback |
| Spec phrase "formatted and mounted declaratively by OpenTofu" | Same DO docs. OpenTofu only formats (initial_filesystem_type); mounting is done by DO cloud-init at droplet creation when the volume is passed to `digitalocean_droplet.volume_ids` | unconfirmed wording; the droplet `volume_ids` path (not a separate attachment resource) is the one most likely to auto-mount |
| Volume name determines mount path `/mnt/<volume-name>` | DO docs examples `/mnt/volume-sfo2-01`; name sanitisation (dashes vs underscores) not documented | unconfirmed |
| Ubuntu 26.04 LTS droplet image slug `ubuntu-26-04-x64` | docs.digitalocean.com/notes/2026/ubuntu-26-04 (available 2026-07-01, verified 2026-07-02) | confirmed |
| Docker apt repo supports Ubuntu 26.04 (codename `resolute`) | Docker's install page is codename-generic (examples noble); computingforgeeks (April 2026) reports docker-ce 29.4.0 on 26.04 from the official repo | unconfirmed from Docker's official matrix; likely true. Verify with `apt list -a docker-ce` on first droplet |
| `community.digitalocean.digitalocean` inventory plugin name and file naming | Plugin source DOCUMENTATION: config file must end in `do_hosts`, `digitalocean` or `digital_ocean` (.yml/.yaml) | confirmed |
| Plugin tag filtering | `filters` option (added 1.5.0) with Jinja expressions; tags only appear as `do_tags` if `tags` is added to `attributes` (not a default) | confirmed, with a gotcha: add `tags` to `attributes` |
| Plugin groups composed from tags | `keyed_groups` / `groups` / `compose` come from the `constructed` fragment; keyed_groups with `do_tags` shown in examples | confirmed. `groups` itself has no example; use keyed_groups |
| Plugin needs only `DIGITALOCEAN_TOKEN` | Doc fragment lists env vars `DO_API_TOKEN`, `DO_API_KEY`, `DO_OAUTH_TOKEN`, `OAUTH_TOKEN`; `DIGITALOCEAN_TOKEN` is not listed in the fragment text I could read (the fragment says "several other environment variables" exist, truncated) | wrong or unconfirmed as written. The OpenTofu provider reads `DIGITALOCEAN_TOKEN`; the Ansible plugin likely needs `DO_API_TOKEN` or `oauth_token: "{{ lookup('env','DIGITALOCEAN_TOKEN') }}"`. Spec's "needing only DIGITALOCEAN_TOKEN" should be tested |
| Public IPv4 as ansible_host | Plugin docs fetched did not show `use_private_network` option; default behaviour not confirmed | unconfirmed |
| Grafana Cloud synthetic monitoring free tier allows a new check | Third-party blog: 100k API and 10k browser executions per month. Grafana billing doc gives formula `probes x tests x duration x (43,200 / frequency)` but no free quota; official pricing page not fetched | unconfirmed (numbers secondary). A single HTTP check at 1 minute from 1 probe is about 43k/month, from 3 probes about 130k, exceeding 100k. Choose probe count and frequency accordingly; the existing checks also count |
| ansible-lint `var-naming[no-role-prefix]` role-name prefix behaviour | docs.ansible.com lint var-naming: "Variables names from within roles should use `role_name_` as a prefix"; underscores before the prefix accepted; vars passed to include_role/import_role should carry the role prefix; task-scoped vars exempt | confirmed in principle; the docs do not say whether defaults/vars files are checked |
| Rename `raspi_` to `fantasy_hockey_` passes ansible-lint | Repo: role is `ansible/roles/raspi/fantasy-hockey` with vars `raspi_fantasy_hockey_*` (and `raspi_pihole_path` in pihole). Role name is `fantasy-hockey`, so rule expects prefix `fantasy_hockey_` | confirmed by rule text. Note the current `raspi_` prefix is already a non-role-name prefix. If the role moves under `cloud-configs/.../roles` or stays at `ansible/roles/raspi/` keep the directory name `fantasy-hockey` |
| Pinned CI images: `pipelinecomponents/ansible-lint:0.79.33`, `chef/inspec:5.22.76` | docker-compose.yml; spine table at line 127 labels `0.79.33` as "ansible-lint". It is the image's own version, not the ansible-lint version (ansible-lint current line is v26 per Docker Hub tags). Tag existence not verifiable via search | unconfirmed; label is misleading |
| InSpec 5.x EOL 2027-08-31 (spine "Open Items") | Spine says verified via web research earlier; not re-checked here | unconfirmed (not re-verified) |
| Chef Infra Server EOL Nov 2026 | Same, not re-checked | unconfirmed (not re-verified) |
| Not re-checked (named in cloud spec) | Caddy (auto HTTPS), nginx, `doctl`, DO "improved metrics" agent, Dependabot docker-compose bumps, which OpenTofu linter (TFLint chosen or open) | unconfirmed, out of scope of the AD-10 core |

## Top findings

1. Spaces `use_lockfile` is unverified. The E5 requirement "shared locked state" (localhost and CI alternating) depends on it, and there is no DynamoDB fallback on Spaces. Test a concurrent lock before committing, or choose another backend.
2. `DIGITALOCEAN_TOKEN` is not a documented env var for the `community.digitalocean` inventory plugin (`DO_API_TOKEN` and others are). Set `oauth_token` from the env lookup in the inventory file, or export both. Also add `tags` to `attributes`, otherwise tag filters and keyed_groups see nothing.
3. DO docs say automatic format and mount applies only at volume creation and give no fixed `/mnt/<name>` rule; OpenTofu does not itself mount. Plan an Ansible mount with fstab (`nofail`) as a fallback, and verify across a reboot.
4. Synthetic monitoring free tier (100k API executions) is only from a third-party source, and one check at 1-minute frequency from a few probes can exceed it; tune frequency and probes.
5. Version labels: `0.79.33` is the pipelinecomponents image version, not ansible-lint; OpenTofu 1.12.x and provider 2.9x are current enough but pin from the official registry at implementation time. Confirmed: slug `ubuntu-26-04-x64`, Docker repo likely supports `resolute`.
