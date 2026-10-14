# Provisioning

Droplets are configured with Ansible from `configs-cloud/digital-ocean/ansible`. No host is listed anywhere: the inventory asks the DigitalOcean API for the droplets, so a new or replaced droplet is found again without editing a file.

## Dynamic Inventory

`inventory/digitalocean.yml` configures the `community.digitalocean.digitalocean` inventory plugin:

- The token is passed explicitly as `oauth_token` from `lookup('env', 'DIGITALOCEAN_ACCESS_TOKEN')`. See [API Token](api-token.md).
- Nothing is filtered: every droplet in the account is part of the inventory.
- `tags` is part of the plugin `attributes`. `keyed_groups` makes one group per droplet tag, named exactly like the tag. So every stage tag from OpenTofu (`dev`, `test`, `prod`) and every extra tag (`fantasy-hockey`) becomes a group, without listing them in the inventory.
- Each droplet is named after itself, which does not resolve in DNS, so `compose` sets `ansible_host` to the droplet's own public IPv4 (not the reserved IP).
- `compose` sets `ansible_user` to `root` (the only user on a droplet) and `StrictHostKeyChecking=accept-new`, so the first connection to a new droplet does not prompt for its host key. A changed host key is still refused, see below.

| Group            | Members                                         |
|------------------|-------------------------------------------------|
| `ubuntu`         | All droplets whose image distribution is Ubuntu |
| `dev`            | All droplets with the stage tag `dev`           |
| `test`           | All droplets with the stage tag `test`          |
| `prod`           | All droplets with the stage tag `prod`          |
| `fantasy-hockey` | All droplets with the tag `fantasy-hockey`      |
| any other tag    | All droplets with that tag                      |

A tag group exists only while at least one droplet carries the tag. Today the groups are `ubuntu`, `prod` and `fantasy-hockey`.

`provision.yml` targets `ubuntu`, so it provisions every Ubuntu droplet in the account, of every stage. To provision one stage only, pass `--limit dev`, `--limit test` or `--limit prod` to `ansible-playbook`.

`compose` also sets `alloy_stage` (the droplet name prefix, `prod` for `prod-fantasy-hockey`, so the stage comes from OpenTofu only) and `alloy_environment` (`digital-ocean`). Check them with `ansible-inventory -i configs-cloud/digital-ocean/ansible/inventory --host prod-fantasy-hockey`.

The tag `fantasy-hockey` is set through the optional `tags` list of the droplet map, see [Droplet](droplet.md). The collections `community.digitalocean` (inventory plugin) and `community.general` (the fleet Alloy role uses its `capabilities` module) are pinned third-party dependencies in `ansible/requirements.yml`; the tasks install them before Ansible runs.

## provision.yml

`playbooks/provision.yml` targets the generic group `ubuntu` and connects as `root`. It has two plays.

The first play, `Wait for new droplets`, gathers no facts, so it does not connect before it is ready. A droplet that `deploy` just created may not accept SSH yet, and cloud-init may still hold the apt lock:

- It fails with a clear message when the inventory found no public IPv4 and so could not set `ansible_host` (inside a task, `ansible_host` would otherwise fall back to the droplet name, which does not resolve).
- `wait_for_connection` waits up to 5 minutes for SSH.
- `cloud-init status --wait` waits up to 10 minutes for cloud-init to finish. Exit code 2 (done with recoverable errors) is accepted; exit code 1 (critical error) or the timeout stops the run for that droplet. See the cause with `cloud-init status --long` on the droplet.

A droplet that fails here is left out of the second play; other droplets are still provisioned. The play does not wait for the apt lock that apt-daily or unattended-upgrades may take after cloud-init; the apt tasks wait up to 60 seconds for it (`lock_timeout`).

On a droplet that is already up, the play passes at once and reports no change. The second play runs these roles in this order. Fleet roles come from `configs-homelab/ansible/roles` through relative paths, cloud roles from `ansible/roles`:

- `bash` (only `11-bash-config-root`): aliases and the root prompt `ps1_root` in `/root/.bashrc`. The prompt is the root prompt of the local ubuntu machines, defined in `ansible/vars/main.yml`.
- `packages` (only `basics`): the basic command line tools of the fleet, such as `curl`, `htop`, `jq`, `ncdu`, `nmap`, `tree` and `vim`, plus `pre-commit`, `python3-pip` and `auditd` (list in `packages/tasks/main/10-basics.yml`).
- `docker`: Docker from the Docker apt repository.
- `swap` (cloud role in `ansible/roles/swap`): a 1 GiB swap file `/swapfile` (`swap_file_size_mb` in the role defaults), mode `0600`, enabled with `swapon` and kept in `/etc/fstab`. A 1 GB droplet has no swap by default, so memory pressure would kill processes silently.
- `grafana-cloud/exporters` (fleet role): cAdvisor as the docker compose project in `/opt/grafana-cloud/exporters`, the same as on the homelab nodes. `ansible/vars/main.yml` sets `exporters_cadvisor_bind_address: 127.0.0.1`, so port `9110` is published on localhost only: the droplet has a public IP and no firewall, and Alloy scrapes `localhost:9110`. It runs after Docker and the swap file, so the 1 GB droplet has swap before cAdvisor starts, and before Alloy, which scrapes it.
- `grafana-cloud/alloy` (fleet role): installs Grafana Alloy from the Grafana APT repo and runs it as the systemd service `alloy`, with the secrets from `configs-homelab/ansible/vars/grafana-vault.yml`. `ansible/vars/main.yml` sets `alloy_config_template` to the cloud config and `alloy_fleet_extras: false`, see [Alloy and Labels](#alloy-and-labels).
- `motd` (cloud role in `ansible/roles/motd`): the login banner, see [Login Banner (MOTD)](#login-banner-motd).

The playbook asks for the vault password (`--ask-vault-pass`). A second run ends with `changed=0`, unless a new version of one of the basic command line tools was released since the last run: `packages` installs them with `state: latest`, so it upgrades them and reports a change. The fleet `alloy` role writes the cloud config directly and restarts Alloy only through its `Restart Alloy` handler when something it reads changed.

## Alloy and Labels

The droplet runs the same fleet Alloy role as the homelab, with two variables from `ansible/vars/main.yml` (play vars, which outrank the role defaults):

- `alloy_config_template: "{{ playbook_dir }}/../templates/alloy/config.alloy.j2"` writes the cloud config (`ansible/templates/alloy/config.alloy.j2`) to `/etc/alloy/config.alloy` instead of the fleet config. The fleet config with `remotecfg` never runs on the droplet.
- `alloy_fleet_extras: false` leaves out the GitHub token file, the eBPF capabilities on the Alloy binary and the capability lines in the systemd override. On a droplet provisioned before this, the first run deletes `/etc/alloy/github.token`, clears the binary capabilities with `setcap -r` and rewrites the override, then restarts Alloy once.

The cloud config has no GitHub, Ollama, FRITZ!Box, Beyla or fleet-management blocks. It ships OS metrics (node exporter), Alloy health, journal logs, Docker logs and cAdvisor metrics, and scrapes the app at `localhost:8080/metrics` (job `fantasy-hockey`). Until the app is [deployed](deployment.md), that target reports `up=0` and Alloy logs no error. Provisioning runs cAdvisor (see above), so its target `integrations/cadvisor` reports `up=1`. With `--docker_only=true`, cAdvisor reports the Docker containers of the droplet, such as the app and nginx.

`environment=digital-ocean` and `stage=prod` are `external_labels` of the Prometheus remote write and the Loki write, so every series and log line carries them. The template is validated by `lint-alloy-config` together with the fleet template.

Homelab nodes carry `environment=homelab` and no `stage` label, set by the fleet Alloy role from its variable `alloy_environment`. The DigitalOcean inventory sets that variable to `digital-ocean`. Filter with `environment="homelab"` or `environment="digital-ocean"`, and use `stage` only for cloud series.

Verify in Grafana Cloud (Explore):

```text
up{environment="digital-ocean", stage="prod"}
up{job="integrations/cadvisor", environment="digital-ocean", stage="prod"}
node_memory_SwapTotal_bytes{environment="digital-ocean", stage="prod"}
{environment="digital-ocean", stage="prod"}
```

On the droplet: `swapon --show` lists `/swapfile` once, `systemctl is-active alloy` prints `active`, `getcap $(command -v alloy)` prints nothing, `ls /etc/alloy` shows no `github.token`, `grep -c remotecfg /etc/alloy/config.alloy` prints `0`, and `docker ps` lists `cadvisor` with `127.0.0.1:9110->8080/tcp`. From outside, `curl http://<reserved-ip>:9110/` cannot connect.

## Login Banner (MOTD)

The MOTD is built at login by `pam_motd`, which runs every executable script in `/etc/update-motd.d/` (`sshd` has `PrintMotd no` and there is no static `/etc/motd`). The `motd` role adds three scripts:

| Script       | Prints                                                                                                                                                                         |
|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `00-banner`  | A blank line, the ASCII art from `/usr/local/share/motd/banner.txt` (stored once as `files/banner.txt` in the role), a blank line                                              |
| `10-os-line` | `Welcome to <PRETTY_NAME> (GNU/Linux <kernel release> <architecture>)` and a blank line, computed from `/etc/os-release` and `uname` (same format as Ubuntu's `00-header`)     |
| `20-updates` | `<N> update(s) can be applied immediately.`, `To see these additional updates run: apt list --upgradable` and a blank line, without the ESM lines; nothing when the count is 0 |

The OS line and the update info are read at login, so they follow a new kernel or new updates without provisioning again. The update info comes from Ubuntu's cached stamp `/var/lib/update-notifier/updates-available`, which Ubuntu's apt and dpkg hooks refresh. `apt-check` is not run at login because it costs about 2.8 s of CPU on this droplet.

All other default scripts are disabled, except `98-reboot-required`, which prints `*** System restart required ***` after the update info when a reboot is pending:

- Regular files lose their exec bit (`pam_motd` skips non-executable scripts). dpkg judges conffile changes by content, so a package upgrade that ships a changed or new script re-enables it until the next provision run.
- `50-landscape-sysinfo` is a symlink that `landscape-common` recreates on upgrade. The role sets the debconf question `landscape-common/sysinfo` to `Do not display sysinfo on login` and removes the symlink (never its target).

See the MOTD without logging in:

```bash
ssh root@<droplet-ip> 'run-parts --lsbsysinit /etc/update-motd.d | cat -A'
```

## Tasks

```bash
task cloud:digital-ocean:ansible:inventory   # droplets and their groups
task cloud:digital-ocean:ansible:provision   # run provision.yml
task cloud:digital-ocean:deploy              # full pipeline: opentofu:apply, then ansible:provision
```

`ansible:provision` (and with it `deploy`) asks for the vault password. All three stop early when `DIGITALOCEAN_ACCESS_TOKEN` is not set.

## Replaced Droplet and Host Key

A replaced droplet has the same tags but a new public IP and a new SSH host key. The inventory finds it again. If SSH reports a changed host key, remove the old entry first:

```bash
ssh-keygen -R <old-droplet-ip>
```
