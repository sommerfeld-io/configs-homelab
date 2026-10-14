# Deployment

The fantasy hockey app runs as docker compose on the droplets with the tag `fantasy-hockey`: the app container and an nginx container in front of it. It is reachable over plain HTTP at `http://<reserved-ip>` (port 80). HTTPS, a domain, backups and alerts are not part of this setup.

## deploy-fantasy-hockey.yml

`configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml` targets the inventory group `fantasy-hockey` (one group per droplet tag, see [Provisioning](provisioning.md)). Ansible warns that the hyphen in the group name is not a valid character; this is accepted. The play connects as `root` and needs a provisioned droplet: `provision.yml` installs Docker, so the `docker` group exists before the deploy adds a user to it.

The play loads the secrets from the vault file with an `include_vars` task, then runs the cloud role `ansible/roles/fantasy-hockey`. The role runs these steps in this order:

1. **Volume check (`tasks/main.yml`):** it fails, before anything is written, when `fantasy_hockey_volume_mount` (`/mnt/prod_fantasy_hockey_data`) is not a mount point, naming the missing mount. A second check fails when `fantasy_hockey_path` is not below that mount, for example because the vault overrides it. It compares the normalized path, so a path that leaves the mount through `..` fails too. The app data must live on the volume, not on the droplet's disk.
2. **User (`tasks/user.yml`):** the `docker` role of the roles collection (only `50-user`) creates the user `fantasy-hockey` with `/bin/bash` and a home folder from `/etc/skel`, and adds it to the `docker` group.
3. **Prompt (`tasks/user.yml`):** the `bash` role (only `10-bash-config`) writes the exports, aliases and the prompt to `/home/fantasy-hockey/.bashrc`. The prompt is the role default `fantasy_hockey_ps1`, the orange `ubuntu_server` prompt of the homelab without the git branch.
4. **Files (`tasks/files.yml`):** the deploy directory, the compose file, the nginx config, `.env` and the seeded data file.
5. **App (`tasks/main.yml`):** it starts the stack as `fantasy-hockey`, restarts it when a config file changed and asserts that both containers run.

The full `docker` role does not run here: it installs Docker with `state: latest`, which would report a change whenever Docker has a new release. `provision.yml` stays root-only and does not create the user.

The play sets `default_user: fantasy-hockey` as a play variable. It has no `vars_files` and does not load `ansible/vars/main.yml`, because `vars_files` outrank play variables and that file sets `default_user: root` for provisioning. Loading the vault with `include_vars` instead of `vars_files` also keeps the playbook in the ansible-lint run, whose syntax check cannot decrypt the vault. It sets `ansible_pipelining: true`: the docker tasks become the non-root user `fantasy-hockey`, and without pipelining Ansible would need ACLs on the droplet to hand its temporary files to that user.

A second run reports `changed=0`.

## User fantasy-hockey

`fantasy-hockey` owns the deploy directory and runs `docker compose` through its `docker` group membership, so the stack does not run as root. The user has no SSH key and no password. Log in as `root` and switch to it:

```bash
ssh root@<droplet-ip>
sudo -iu fantasy-hockey
cd /mnt/prod_fantasy_hockey_data/fantasy-hockey
docker compose ps
```

## Paths and Files

The deploy directory is `fantasy_hockey_path`, `/mnt/prod_fantasy_hockey_data/fantasy-hockey` on the volume, so the data file survives a droplet replacement, see [Replacement](replacement.md).

| Path                      | Owner, mode                    | Content                                                                                                                                         |
|---------------------------|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| `docker-compose.yml`      | `fantasy-hockey`, `0644`       | Static compose file: `app` (`sommerfeldio/fantasy-hockey`, port 8080 on `127.0.0.1` only) and `nginx` (port 80), both `restart: unless-stopped` |
| `nginx/default.conf`      | `fantasy-hockey`, `0644`       | Proxies `/` to the app and answers `/metrics` with 404                                                                                          |
| `.env`                    | `fantasy-hockey`, `0600`       | Project name, session secret and SMTP settings from the vault, read by `docker compose`                                                         |
| `data/`                   | UID 1000, `0755`               | Mounted into the app container at `/data`. UID 1000 is the image's non-root user                                                                |
| `data/fantasy-hockey.yml` | UID 1000, `0644` (when seeded) | The app's data file: players, prediction sets, teams, predictions                                                                               |

When `docker-compose.yml`, `nginx/default.conf` or `.env` changes, the role replaces the file and restarts the stack. The image is pulled only when it is missing (`pull: missing`), so a new image version comes from a change to `docker-compose.yml`.

Alloy (installed by `provision.yml`) scrapes the app at `localhost:8080/metrics` (job `fantasy-hockey`), which the compose file binds to the loopback interface. From outside, nginx answers `/metrics` with 404.

## Seed Rule

`data/fantasy-hockey.yml` is seeded from the role template `fantasy-hockey.yml.j2` only when it does not exist. The players come from the vault, the season and the before-season deadline from the role defaults. Once the file exists, the deploy never touches it again, not its content, owner or mode. The app rewrites the file at runtime and the pool operator edits it by hand, so a deploy must never overwrite live pool data. To start over from the template, delete the file and deploy again.

## Secrets

The secrets are in the Ansible Vault file `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml`: `fantasy_hockey_session_secret`, `fantasy_hockey_smtp_host`, `fantasy_hockey_smtp_port`, `fantasy_hockey_smtp_username`, `fantasy_hockey_smtp_password` and `fantasy_hockey_players`. Edit them with:

```bash
task cloud:digital-ocean:vault:fantasy-hockey
```

The plain variables (`fantasy_hockey_volume_mount`, `fantasy_hockey_path`, `fantasy_hockey_season`, `fantasy_hockey_regular_season_deadline_utc`, `fantasy_hockey_ps1`) are role defaults in `ansible/roles/fantasy-hockey/defaults/main.yml`.

## Tasks

```bash
task cloud:digital-ocean:ansible:deploy-fantasy-hockey   # run deploy-fantasy-hockey.yml
task cloud:digital-ocean:vault:fantasy-hockey            # edit the fantasy hockey secrets
task cloud:digital-ocean:deploy                          # opentofu:apply, ansible:provision, then ansible:deploy-fantasy-hockey
```

The deploy asks for the vault password and stops early when `DIGITALOCEAN_ACCESS_TOKEN` is not set. `deploy` asks for the vault password twice, once for provisioning and once for the app.

## Checks

After a deploy:

- `http://<reserved-ip>` opens the app in a browser outside the home network.
- `curl -s -o /dev/null -w '%{http_code}\n' http://<reserved-ip>/metrics` prints `404`.
- `docker compose ps` as `fantasy-hockey` in the deploy directory lists `fantasy-hockey-app` and `fantasy-hockey-nginx`.
- In Grafana Cloud (Explore), `up{job="fantasy-hockey", environment="digital-ocean", stage="prod"}` is `1`.

## Pi Retirement

The app ran on `pi4-0002` behind a port forward of the home router until the droplet took over. The role moved from `configs-homelab/ansible/roles` to `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey`, and the pi4-0002 play in `configs-homelab/ansible/playbooks/raspi.yml` became a cleanup play. Run it only after the app is verified on the droplet, then remove the port forward in the router.

The cleanup play is tagged `never` and `fantasy-hockey-cleanup`, so `task ansible:raspi` and `task ansible:all` (`all.yml` imports `raspi.yml`) skip it. Only its own task runs it, limited to `pi4-0002`, so the other Pis are not contacted (their plays would still gather facts, and an unreachable Pi would fail the run):

```bash
task ansible:raspi:fantasy-hockey-cleanup
```

The cleanup play targets only `pi4-0002`:

1. It lists the running containers and fails, before removing anything, when a container runs that is neither part of the `fantasy-hockey` project (names starting with `fantasy-hockey-`) nor a fleet container. Fleet containers are the ones the homelab roles run on every Pi, listed in the play variable `fantasy_hockey_pi_fleet_containers`; today that is `cadvisor` from the `grafana-cloud/exporters` role. The failure lists the other containers.
2. When `/opt/fantasy-hockey` exists, it stops and removes the stack with `docker compose down` (`docker_compose_v2`, `state: absent`) and deletes `/opt/fantasy-hockey`.

The Pi's data is deleted without a backup; it is not migrated to the droplet. A second run finds no `/opt/fantasy-hockey` and reports `changed=0`.
