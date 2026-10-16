# Epic 4 Context: App deployment

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Run the fantasy hockey app as docker compose on the DigitalOcean droplet that Epics 2 and 3 created and provisioned, and make it reachable from the internet at the reserved IP over plain HTTP. This replaces the unstable Raspberry Pi deployment behind the home router port forward, so nothing on the home network stays exposed, and the old Pi deployment is removed. The epic also proves that the droplet can be replaced (for example for a newer Ubuntu LTS) while the reserved IP and the data file survive, so a fresh droplet comes up from the repo alone.

## Stories

- Story 4.1: Move fantasy-hockey role and deploy-fantasy-hockey.yml with nginx
- Story 4.2: Dependabot compose bumps for configs-cloud
- Story 4.3: Droplet replacement drill

## Requirements & Constraints

- `http://<reserved-ip>` (port 80, nginx in front of the app on 8080) serves the app from outside the home network. HTTPS, a domain and Caddy are out of scope (a later epic); so are backups, alerts and migrating existing Pi data.
- App data lives on the volume at `/mnt/prod_fantasy_hockey_data/fantasy-hockey`. `fantasy-hockey.yml` is seeded from the default template only when absent. When present, it is never overwritten from the template, only from a backup.
- The deploy creates a dedicated user `fantasy-hockey` (bash config from Ansible, member of the `docker` group). docker compose runs as that user, not as root. `provision.yml` stays root-only and does not create the user.
- A second deploy run changes nothing.
- Containers use `restart: unless-stopped`. No DO firewall, user-data scripts or managed DB, and only one droplet.
- Every new repo-owned role needs a Molecule scenario. Test containers are unprivileged, with no host mounts and no systemd, because a privileged systemd container hung up the host's desktop session. Pull-request CI never gets the vault password.
- After the move, no reference to `configs-homelab/ansible/roles/raspi/fantasy-hockey` remains in `raspi.yml`, `configs-homelab/ansible/taskfile.yml` or `.github/dependabot.yml`.
- Pi cleanup runs only after the app is verified reachable on the droplet. It is scoped to pi4-0002 and checks first that no other service runs in containers there. It removes `/opt/fantasy-hockey` and that Pi's containers.
- Every story updates the docs under `docs/cloud/digital-ocean` in the same change. Docs are organized by topic. Check pages from earlier stories for drift, not only the new section.
- Every step runs through go-task entry points and passes `task lint`. Check that the `fantasy_hockey_` var rename passes ansible-lint.
- The Alloy scrape of the app's `:8080/metrics` (configured in Epic 3) must be re-checked for `environment=digital-ocean` and `stage=prod` once the app runs.
- Replacement (Story 4.3): changing the image slug and re-running apply, provision and deploy replaces the droplet. The reserved IP and the volume holding `fantasy-hockey.yml` are re-attached, the app returns at the same address after a short outage, and the procedure is documented.

## Technical Decisions

- The fantasy-hockey compose role is the only role that moves out of `configs-homelab`. Move it with `git mv` from `configs-homelab/ansible/roles/raspi/fantasy-hockey` into `configs-cloud/digital-ocean/ansible/roles`, together with its files, README and defaults, and rename its vars to the `fantasy_hockey_` prefix. Other roles are reused through relative paths, not `roles_path`.
- The role's `defaults/main.yml` is fully vault-encrypted. Split it: secrets go into a vault file that the deploy playbook loads, plain defaults stay in the role, and the Molecule scenario uses test values.
- `deploy-fantasy-hockey.yml` targets the `fantasy-hockey` inventory group (discovered by tag). It sets `default_user: fantasy-hockey` so the reused submodule `docker` role (user creation and `docker` group) and `bash` role (`.bashrc` with `ps1`) apply to the new user. It defines a non-root `ps1`. Whether the user gets an SSH key is decided when Story 4.1 is planned; nobody has asked for one.
- The hyphenated group name `fantasy-hockey` raises an Ansible warning. This is accepted.
- New tasks: `cloud:digital-ocean:vault:fantasy-hockey` (moved from the homelab taskfile) and `cloud:molecule:test:fantasy-hockey`. Add the role to the `molecule-cloud` matrix in `pipeline.yml`.
- The scenario cannot run Docker. It verifies the user, files, templates and the seed-only-when-absent rule; starting the containers is verified on the droplet.
- `raspi.yml`'s pi4-0002 play only ran this role, so it is replaced by the cleanup play.
- The Dependabot entry for the compose images moves with the role, so a bump is a change under `configs-cloud/digital-ocean`. The automatic redeploy after a bump comes with the GitHub Actions epic. A bump that replaces the droplet is an accepted risk.
- Droplet facts: Ubuntu 26.04, 1 vCPU and 1 GB RAM with swap, and the volume mounted at `/mnt/prod_fantasy_hockey_data`. OpenTofu protects the volume and the reserved IP with `prevent_destroy` and is the only owner of SSH key injection.
- The `deploy` task already waits for a new droplet (connection and cloud-init). A first-boot apt lock ("Could not get lock") is not handled yet; watch for it in the replacement drill, along with an `ansible_host` that is still undefined while the new droplet has no public IPv4.

## Cross-Story Dependencies

- Depends on Epic 2 (droplet, reserved IP, volume, `prevent_destroy`) and Epic 3 (tag inventory with the `fantasy-hockey` group, Docker, Alloy scrape config, the cloud Molecule harness and its rule).
- Story 4.1 moves the Dependabot entry. Story 4.2 only makes sure bumps change the configs-cloud compose file.
- Story 4.3 needs Story 4.1. Re-running provision and deploy brings back the banner, the `fantasy-hockey` user and the app.
- Downstream: Epic 5 builds the dashboard and the synthetic check on the running app. Epic 6 runs `deploy-fantasy-hockey.yml` from CI and adds the syntax check that needs vault-free playbooks.
