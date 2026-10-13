# Provisioning

Droplets are configured with Ansible from `configs-cloud/digital-ocean/ansible`. No host is listed anywhere: the inventory asks the DigitalOcean API for the droplets, so a new or replaced droplet is found again without editing a file.

## Dynamic Inventory

`inventory/digitalocean.yml` configures the `community.digitalocean.digitalocean` inventory plugin:

- The token is passed explicitly as `oauth_token` from `lookup('env', 'DIGITALOCEAN_ACCESS_TOKEN')`. See [API Token](api-token.md).
- A filter keeps only droplets tagged `prod` (the stage tag from OpenTofu).
- `tags` is part of the plugin `attributes`, so groups can be composed from them.
- Each droplet is named after itself, which does not resolve in DNS, so `compose` sets `ansible_host` to the droplet's own public IPv4 (not the reserved IP).
- `compose` sets `ansible_user` to `root` (the only user on a droplet) and `StrictHostKeyChecking=accept-new`, so the first connection to a new droplet does not prompt for its host key. A changed host key is still refused, see below.

| Group            | Members                                                  |
|------------------|----------------------------------------------------------|
| `ubuntu`         | All selected droplets whose image distribution is Ubuntu |
| `fantasy-hockey` | All selected droplets with the tag `fantasy-hockey`      |

`compose` also sets `alloy_stage` (the droplet name prefix, `prod` for `prod-fantasy-hockey`, so the stage comes from OpenTofu only) and `alloy_environment` (`digital-ocean`). Check them with `ansible-inventory -i configs-cloud/digital-ocean/ansible/inventory --host prod-fantasy-hockey`.

The tag `fantasy-hockey` is set through the optional `tags` list of the droplet map, see [Droplet](droplet.md). The collections `community.digitalocean` (inventory plugin) and `community.general` (the fleet Alloy role uses its `capabilities` module) are pinned third-party dependencies in `ansible/requirements.yml`; the tasks install them before Ansible runs.

## provision.yml

`playbooks/provision.yml` targets the generic group `ubuntu` and connects as `root`. It reuses roles from `configs-homelab/ansible/roles` through relative paths:

- `docker`: Docker from the Docker apt repository.
- `bash` (only `11-bash-config-root`): aliases and the root prompt `ps1_root` in `/root/.bashrc`. The prompt is the root prompt of the local ubuntu machines, defined in `ansible/vars/main.yml`.

- `swap` (cloud role in `ansible/roles/swap`): a 1 GiB swap file `/swapfile` (`swap_file_size_mb` in the role defaults), mode `0600`, enabled with `swapon` and kept in `/etc/fstab`. A 1 GB droplet has no swap by default, so memory pressure would kill processes silently.
- `grafana-cloud/alloy` (fleet role): installs Grafana Alloy from the Grafana APT repo and runs it as the systemd service `alloy`, with the secrets from `configs-homelab/ansible/vars/grafana-vault.yml`.
- `alloy-config` (cloud role in `ansible/roles/alloy-config`): the fleet role writes the fleet config, so this role then replaces `/etc/alloy/config.alloy` with the cloud config and restarts Alloy.
- `motd` (cloud role in `ansible/roles/motd`): the login banner, see [Login Banner (MOTD)](#login-banner-motd).

The playbook asks for the vault password (`--ask-vault-pass`). The swap, motd and cloud config template tasks report no change on a second run. The fleet `alloy` role always reports changes (forced template, `state: restarted`), and because it rewrites the fleet config each run, the copy of the cloud config over `config.alloy` and the Alloy restart report changed too.

## Alloy and Labels

The cloud config (`alloy-config/templates/config.alloy.j2`) has no GitHub, Ollama, FRITZ!Box, Beyla or fleet-management blocks. It ships OS metrics (node exporter), Alloy health, journal logs, Docker logs and cAdvisor metrics, and scrapes the app at `localhost:8080/metrics` (job `fantasy-hockey`). Until the app is deployed (Epic 4), that target reports `up=0` and Alloy logs no error. The same applies to cAdvisor while no cAdvisor container runs.

`environment=digital-ocean` and `stage=prod` are `external_labels` of the Prometheus remote write and the Loki write, so every series and log line carries them. The template is validated by `lint-alloy-config` together with the fleet template.

Homelab nodes carry `environment=homelab` and no `stage` label, set by the fleet Alloy role from its variable `alloy_environment`. The DigitalOcean inventory sets that variable to `digital-ocean`, so even during the few seconds the fleet config runs on the droplet on each provision, its series are never labeled `homelab`. Filter with `environment="homelab"` or `environment="digital-ocean"`, and use `stage` only for cloud series.

Verify in Grafana Cloud (Explore):

```text
up{environment="digital-ocean", stage="prod"}
node_memory_SwapTotal_bytes{environment="digital-ocean", stage="prod"}
{environment="digital-ocean", stage="prod"}
```

On the droplet: `swapon --show` lists `/swapfile` once, `systemctl is-active alloy` prints `active`.

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
