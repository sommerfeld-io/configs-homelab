# Tests

The roles the droplet runs have [Molecule](https://docs.ansible.com/projects/molecule) scenarios. Molecule applies the role to a disposable Docker container, applies it a second time to prove that nothing changes, and then asserts the result. A broken role fails here and in CI instead of on the droplet. No test touches the droplet or needs the vault password. The tests need internet access: Docker pulls `ubuntu:26.04`, `prepare.yml` installs packages from the Ubuntu archive, and the `alloy` scenario downloads Alloy from `apt.grafana.com`, so an outage there fails the `alloy` scenario.

The scenarios live in `configs-cloud/digital-ocean/tests/molecule/`, one per role:

```text
configs-cloud/digital-ocean/tests/molecule/
  taskfile.yml       # included in configs-cloud/taskfile.yml: `task cloud:molecule:*`
  base.yml           # shared Molecule config: platform, driver, test sequence
  prepare.yml        # shared container setup before the role runs
  motd/molecule/default/{molecule,converge,verify}.yml
  alloy/molecule/default/{molecule,converge,verify}.yml
  fantasy-hockey/molecule/default/{molecule,converge,verify}.yml, vars/test-vars.yml
```

## Tasks

| Task                              | What it does                                           |
|-----------------------------------|--------------------------------------------------------|
| `task cloud:molecule:test`        | Run every scenario: `motd`, `alloy`, `fantasy-hockey`  |
| `task cloud:molecule:test:<role>` | Run one scenario, e.g. `task cloud:molecule:test:motd` |

Each scenario runs dependency, destroy, create, prepare, converge, idempotence, verify and destroy. Molecule runs through `uvx`, so it needs Docker and `uv` but no local Molecule install. The collections come from the pinned `configs-cloud/digital-ocean/ansible/requirements.yml`, the same file provisioning uses.

## Test Container

The droplet runs Ubuntu only, so `base.yml` has a single platform: the plain `ubuntu:26.04` image (the droplet's release). The container is not privileged, has no host mounts and runs no systemd, so a test can never change the host. A privileged container with systemd as PID 1 was tried first. A privileged container sees the host's `/dev`, and each time its systemd booted, the host's graphical session on `/dev/tty1` got SIGHUP and the screens stayed black until the host was rebooted.

`prepare.yml` adds what the droplet image ships and the Docker image lacks, so the roles run unchanged:

- the packages `python3`, `ca-certificates`, `python3-apt`, `cron`, `libcap2-bin`, `gnupg`, `sudo`, `landscape-common` and `update-notifier-common`
- the `docker` group (Docker is installed by `provision.yml` on the droplet; the Alloy role and the `fantasy-hockey` scenario add their users to that group)
- a stub `/usr/local/bin/systemctl` that answers the Alloy role's service calls: every unit is loaded, enabled and active, every other command succeeds. Every call is logged to `/var/log/systemctl-stub.log`. The scenarios therefore do not prove that Alloy starts, only that the role restarts it once in converge and not in the idempotence run.

## Scenarios

| Scenario         | Role under test                                                                                                                                                      | Verify asserts                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `motd`           | `configs-cloud/digital-ocean/ansible/roles/motd`                                                                                                                     | `20-updates` output for update stamps with zero, one and several (the droplet's real stamp) pending updates, byte for byte; only `00-banner`, `10-os-line`, `20-updates` and `98-reboot-required` are executable; the `50-landscape-sysinfo` symlink is gone                                                                                                                                                                                                                                                                                        |
| `alloy`          | fleet role `configs-homelab/ansible/roles/grafana-cloud/alloy` with `alloy_fleet_extras: false` and the cloud template                                               | no `github.token`, no capabilities on the Alloy binary, `config.alloy` has `environment = "digital-ocean"` and `stage = "prod"` in both `external_labels` blocks and no `github` or `remotecfg` block; Alloy was restarted exactly once                                                                                                                                                                                                                                                                                                             |
| `fantasy-hockey` | `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey` with `tasks_from: user` (`docker` role `50-user`, `bash` role `10-bash-config`), then `tasks_from: files` | the user `fantasy-hockey` has `/bin/bash` and is in the `docker` group; `.bashrc` has the prompt line of the role default `fantasy_hockey_ps1` without `__git_ps1`; owners and modes of the deploy folder, `nginx/`, `docker-compose.yml`, `nginx/default.conf`, `.env` (`0600`), `data/` and the data file (UID 1000); `.env` holds the test values; the seeded data file has the test season, players and deadline; seed rule: after the data file is edited by hand, a second run of the file tasks leaves its content, owner and mode unchanged |

The `alloy` scenario loads the droplet's `configs-cloud/digital-ocean/ansible/vars/main.yml` and sets the variables the droplet gets from the inventory and the vault in its converge playbook: `alloy_environment: digital-ocean`, `alloy_stage: prod` and fake Grafana Cloud secrets.

The `fantasy-hockey` scenario cannot run Docker in the unprivileged container, so it does not start the stack: it runs only the role's `tasks/user.yml` and `tasks/files.yml`, not `tasks/main.yml`. Starting the containers and the restart on a config change are verified on the droplet (see [Deployment](deployment.md#checks)). The volume and path guards of `tasks/main.yml` need no Docker, so verify tests them: it runs the role's `main` entry four times inside `block`/`rescue`, each with its own user and path (a volume that is not mounted, a path outside a mounted path, a path that leaves it through `..`, and a sibling path that only starts with the mount path; `/etc/hostname` stands in for the volume because Docker bind-mounts it). It asserts that each run was stopped by its guard and that neither the user nor the folder exists. The test values (user, deploy path `/srv/fantasy-hockey` instead of the volume, fake secrets and players) are in the scenario's `vars/test-vars.yml`, which converge and verify both load; no vault is read. They are not in `molecule.yml`, because Molecule expands `${...}`. The prompt is not a test value: the role passes its default `fantasy_hockey_ps1`, and verify loads `defaults/main.yml` (into its own namespace, so the defaults do not outrank the test values) and checks `.bashrc` against it.

The `swap` role has no scenario. `swapon` cannot run in an unprivileged container, and a privileged one is not allowed (see above). The role is checked on the droplet: a second `task cloud:digital-ocean:ansible:provision` run reports no change for its tasks (the `docker` and `packages` tasks still report a change when a new Docker or package release came out, see [Provisioning](provisioning.md#provisionyml)).

The fleet role `grafana-cloud/exporters` (cAdvisor) has no scenario either. It runs a docker compose project and asserts that the `cadvisor` container runs, and the unprivileged test container has no Docker. It is checked on the droplet in the same way: a second provision run reports no change for its tasks (a Docker upgrade in the same run restarts the `cadvisor` container), and `docker ps` lists `cadvisor` with `127.0.0.1:9110->8080/tcp`.

## CI

The `molecule-cloud` job in `.github/workflows/pipeline.yml` runs the scenarios as a matrix (`motd`, `alloy`, `fantasy-hockey`) after the linters, ShellCheck and the InSpec checks, next to the `molecule` job for the homelab roles. `generate-docs`, and through it the release, waits for both. See [Pipelines](../../pipelines.md).

## Adding a Role

A new role is not done without a scenario. For a new role under `configs-cloud/digital-ocean/ansible/roles`:

1. Add `<role>/molecule/default/molecule.yml`, `converge.yml` and `verify.yml` following the `motd` scenario.
2. Add a `test:<role>` task to `configs-cloud/digital-ocean/tests/molecule/taskfile.yml` and call it from `test`.
3. Add the role to the `molecule-cloud` matrix in `pipeline.yml`.
4. Put test-only setup in `prepare.yml` or the scenario's converge `pre_tasks`, never in the role. Never make the container privileged or mount host paths into it.
