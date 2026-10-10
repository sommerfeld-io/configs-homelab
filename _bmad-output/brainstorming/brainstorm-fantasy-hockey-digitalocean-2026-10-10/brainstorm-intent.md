# Intent: Fantasy Hockey on DigitalOcean

## Goal and why

Run the fantasy hockey app on a small DigitalOcean droplet, provisioned and deployed gitops-style with OpenTofu, Ansible and GitHub Actions (code in `cloud-configs/digital-ocean/{opentofu,ansible}`).

- The Fritzbox port forward on the Raspberry Pi was unstable, and no door into the home network is wanted.
- Everything must run identically locally (go-task) and in CI.
- The setup must be extensible (more apps, a second droplet, later microVMs or App Platform) but the app is a hobby for about 3 users and prod will never need to scale.
- It must run unattended long-term. The real long-term risk is neglect, not scale.
- "terraform" always means OpenTofu.

## Hard decisions

### Droplet spec

- Basic shared CPU `s-1vcpu-1gb` (about $6/mo), region `fra1`, Ubuntu 26.04 LTS x64, public IPv4, quantity 1.
- Budget about $6 for the droplet plus about $0.20 for the volume. Start small and observe. Resize (CPU/RAM only, never disk) is a one-line OpenTofu change.
- Droplet name starts with `prod-fantasy-hockey` (stage embedded in the name), tag `prod`, DO project `sommerfeld.io` (named explicitly).
- Improved Metrics and DO monitoring enabled. No DO user-data scripts, no managed DB, no DO firewall.
- Droplet is disposable (pets vs cattle). Design the droplet as a reusable module or `for_each` keyed by name and stage so a second droplet (test stage or an unrelated app) is cheap. Keep quantity 1 for now.
- OS upgrade strategy: change the image slug, replace the droplet, rerun provision and deploy. Short outage is acceptable. No in-place dist-upgrade.

### Secrets

- Env var `DIGITALOCEAN_TOKEN` with custom scopes (droplet, ssh_key, volume, reserved IP, project, and firewall or domain only if needed).
- Locally the token is stored in `ansible/vars/vault.yml` and exported into `.bashrc` via `ansible/tasks/bash-secrets.yml` (run from `desktop.yml`). It is not provided by playbooks that target DO.
- Ansible Vault: all vaults share one password. Local runs prompt for it. In CI it comes from an org-level GitHub secret.
- CI needs separate GitHub secrets for the DO token and the vault password, because OpenTofu runs before Ansible and the vault cannot unlock the token. All GitHub secrets are org-level for reuse.
- SSH: locally reuse the existing DO key (`id_rsa.pub`) plus the key named `picon___id_rsa.pub`. For CI (E5 only) create a fresh dedicated keypair whose private key never leaves CI.
- Spaces keys are separate and only needed if a Spaces state backend is chosen.
- The devcontainer must install `doctl`, OpenTofu and all other needed tools.

### State

- E1 uses local OpenTofu state.
- E5 needs shared state between localhost and Actions with locking. Candidate: a DO Spaces bucket as S3-compatible backend (decide in E5).
- Ansible no longer needs OpenTofu state (see inventory).

### Inventory

- DO dynamic inventory plugin (`community.digitalocean`), filtered by tag `prod`, needing only `DIGITALOCEAN_TOKEN`. This replaces the earlier static hard-coded IP and the committed-inventory idea.
- Groups `ubuntu` (provision dependencies, bash prompt) and `fantasy-hockey` (same droplet, runs the service) are composed from tags.
- Same bash prompt as the `ansible/hosts.yml` ubuntu server, with `user@host` in yellow.
- Trap avoided: committing generated inventory into `cloud-configs/digital-ocean` would retrigger the pipeline.
- Role reuse from `ansible/roles` via relative paths (multiple `../`), not `roles_path`, because DO-specific roles may appear. Only the fantasy-hockey compose role moves, into `cloud-configs/digital-ocean/ansible/roles` (vars renamed from `raspi_` to `fantasy_hockey_` if ansible-lint agrees).
- Playbooks: `provision.yml` (bash config, docker, alloy, prompt, swap) and `deploy-services.yml` (fantasy-hockey).

### Labels

- Alloy labels in both the homelab `config.alloy.j2` and the new DO config: `environment` = `homelab` or `digitalocean` (`source` is taken). The DO droplet also carries `stage=prod`.
- `stage` is one concept: define it once and reuse it in tag, droplet name, inventory group and Alloy label.

### Monitoring

- Alloy installed through the existing role `ansible/roles/grafana-cloud`, reusing secrets from `ansible/vars/grafana-vault.yml`. It scrapes the app at `:8080/metrics`, OS metrics and logs, all shipped to Grafana Cloud as in the homelab.
- External availability and latency via existing Grafana Cloud synthetic monitoring (already used from Frankfurt and Paris). This covers the blind spot behind the old Fritzbox failure (external timeouts while internal monitoring showed no downtime).
- Post-deploy smoke test of the public URL in Ansible, in a later epic.
- Observe first. No alerts yet.

### Volume

- 2 GB block volume, ext4, declared in OpenTofu (`initial_filesystem_type` ext4, attached at droplet creation, DO auto-mount). Format and mount are not done in Ansible.
- Data path `/mnt/<volume-name>/fantasy-hockey` (or whatever works best). The app's data path must point at it.
- Volume and reserved IP use `prevent_destroy` so droplet rebuilds keep data and URL. This may change when backup/restore is tackled.
- Data file rule for `fantasy-hockey.yml`: if absent, write the default template. If present, overwrite only from backup, never with template contents. On a fresh droplet: write the default, then override from backup if one exists.

### Exposure

- App listens on 8080. Open to the whole internet.
- Early epics: plain HTTP, nginx on port 80 kept in front of the app, reachable at `http://<reserved-ip>`. The reserved IP is managed by OpenTofu and survives droplet rebuilds.
- Later (E6): HTTPS with a custom domain (`fantasy-hockey.do.sommerfeld.io` or `do.sommerfeld.io/fantasy-hockey`) and Caddy for automatic certificates, replacing nginx. The `<ip>.sslip.io` option is a fallback.
- Rejected: Tailscale and Cloudflare (too complex). App Platform and Load Balancer are not suitable for now.
- The app still runs as docker compose on the droplet.

### Naming and tagging

- Tag `prod`, droplet name `prod-fantasy-hockey...`, DO project `sommerfeld.io`, label `environment=digitalocean` plus `stage=prod`.
- Taskfile: `cloud-configs/taskfile.yml` included in the main taskfile with prefix `cloud`. DO tasks are `cloud:digital-ocean:*`.
- Linters (folderslint, ansible-lint, a new OpenTofu linter, ls-lint kebab-case) cover the new setup. Static tests go into `pipeline.yml` or a new workflow.
- Runtime conventions: Ansible provisions, containers use `restart: unless-stopped`, cron handles regular jobs, Alloy runs as a systemd service.

### Docs requirements

- All setup documented under `docs/cloud/digital-ocean`, with a `mkdocs.yml` nav item "Cloud - Digital Ocean" and multiple pages: what runs where, how it works, how to run provisioning (GitHub Actions preferred), manual setup for localhost, GitHub and DO.
- Explain the dynamic inventory in the docs.
- Use kroki.io diagrams.
- Docs are part of every epic.
- Docs are the only long-term memory, so keep them current.

## Epics and MoSCoW verdicts

Order is delivery order. Everything is runnable locally via the taskfile first.

| Epic | Name                           | Verdict            |
|------|--------------------------------|--------------------|
| E1   | Droplet via OpenTofu (local)   | Must               |
| E2   | Provisioning via Ansible       | Must               |
| E3   | App deployment                 | Must               |
| E4   | Grafana dashboard              | Should             |
| E5   | GitHub Actions                 | Must               |
| E6   | HTTPS, domain, Caddy           | Could              |
| E7   | Operations hardening           | Could              |
| E8   | Backup and restore (last)      | Won't this time    |

### E1 Droplet via OpenTofu

Droplet, tag, project, SSH keys, 2 GB volume (declarative ext4, auto-mount), reserved IP, `prevent_destroy` on volume and IP, local state, provider version pinning, taskfile and linter wiring, devcontainer tools, DO token delivery through vault and bash-secrets, docs.

### E2 Provisioning via Ansible

`provision.yml` with dynamic inventory (groups `ubuntu` and `fantasy-hockey`), bash config and yellow prompt, Docker, Alloy (`environment` and `stage` labels, scrape of app, OS metrics and logs), swap file (Should, because of 1 GB RAM), docs.

### E3 App deployment

`deploy-services.yml`, moved fantasy-hockey compose role with `fantasy_hockey_` vars, nginx on port 80, data on the volume with the seed rule, app reachable at `http://<reserved-ip>`, Dependabot bumps of compose images, docs.

### E4 Grafana dashboard

Comprehensive dashboard in `grafana-cloud/manifests/git-sync/apps`: CPU, memory and more, the app, containers, logs of all containers. Synthetic external check (Should). No alerts.

### E5 GitHub Actions

Workflow `cloud-deployment.yml` triggered by changes in `cloud-configs/digital-ocean` (including Dependabot bumps): OpenTofu, then Ansible provisioning (alloy etc.), then Ansible services. Decoupled from app releases. Org-level secrets, dedicated CI SSH keypair, shared remote state with locking, static tests. A Must, but fifth in order.

### E6 HTTPS, domain, Caddy

Custom domain, Caddy with automatic TLS replacing nginx, app published only on `127.0.0.1:8080` so Alloy scrapes locally while only Caddy exposes 80 and 443.

### E7 Operations hardening

Unattended-upgrades, logrotate and disk cleanup, memory limits (docker `mem_limit`, Alloy `MemoryMax`), post-deploy smoke test, Raspberry Pi decommission, token expiry and Ubuntu EOL planning.

### E8 Backup and restore

Infra concern, not app concern. Scheduled backup (not after each edit) and restore at fresh-droplet startup in the Ansible seed task. Target candidates: DO Spaces, droplet snapshots, private git repo. Relaxing `prevent_destroy` is revisited here.

## Non-goals and deferrals

- No scaling of prod, no zero-downtime migration, no in-place OS upgrades.
- No DO firewall, user-data scripts, managed DB, Tailscale or Cloudflare.
- No HTTPS or custom domain before E6.
- No alerts yet (observe first). Alerting on RAM, OOM kills and disk comes later.
- No backup and restore before E8. The Pi decommission is a Should in the plan but handled with E7 hardening.
- Remote OpenTofu state is deferred until E5.
- A second droplet (test stage or another app) is only prepared for, not built.

## Open questions to verify

- Ubuntu 26.04 image slug on DO (check with `doctl`). The user confirmed DO offers it, but the exact slug and Docker apt repo support still need checking.
- Auto-mount behaviour of the declarative volume (`initial_filesystem_type` ext4 attached at creation): is it mounted under `/mnt/<name>`, and does it persist across reboots and re-attach? Fallback is Ansible mounting, which conflicts with the decision to avoid it.
- Minimum volume size and price (2 GB, about $0.20/mo).
- `community.digitalocean` inventory plugin options: tag filtering, group composition from tags, public IPv4 as `ansible_host`, token via env var.
- Grafana Cloud synthetic monitoring limits and how the existing checks are provisioned.
- Whether unattended-upgrades should move earlier than E7 (currently Could, but the unattended long-term requirement argues for E2).
- Remote state backend for E5 (Spaces or other) and its locking support.
- Whether 1 vCPU and 1 GB RAM suffice for docker, nginx, app and Alloy (swap and limits as mitigation).
- Whether renaming `raspi_` vars to `fantasy_hockey_` passes ansible-lint.
- Choice of OpenTofu linter.
