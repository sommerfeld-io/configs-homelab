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
```

## Tasks

| Task                              | What it does                                           |
|-----------------------------------|--------------------------------------------------------|
| `task cloud:molecule:test`        | Run every scenario: `motd`, `alloy`                    |
| `task cloud:molecule:test:<role>` | Run one scenario, e.g. `task cloud:molecule:test:motd` |

Each scenario runs dependency, destroy, create, prepare, converge, idempotence, verify and destroy. Molecule runs through `uvx`, so it needs Docker and `uv` but no local Molecule install. The collections come from the pinned `configs-cloud/digital-ocean/ansible/requirements.yml`, the same file provisioning uses.

## Test Container

The droplet runs Ubuntu only, so `base.yml` has a single platform: the plain `ubuntu:26.04` image (the droplet's release). The container is not privileged, has no host mounts and runs no systemd, so a test can never change the host. A privileged container with systemd as PID 1 was tried first. A privileged container sees the host's `/dev`, and each time its systemd booted, the host's graphical session on `/dev/tty1` got SIGHUP and the screens stayed black until the host was rebooted.

`prepare.yml` adds what the droplet image ships and the Docker image lacks, so the roles run unchanged:

- the packages `python3`, `ca-certificates`, `python3-apt`, `cron`, `libcap2-bin`, `gnupg`, `sudo`, `landscape-common` and `update-notifier-common`
- the `docker` group (Docker is installed before Alloy on the droplet, and the Alloy role adds its user to that group)
- a stub `/usr/local/bin/systemctl` that answers the Alloy role's service calls: every unit is loaded, enabled and active, every other command succeeds. Every call is logged to `/var/log/systemctl-stub.log`. The scenarios therefore do not prove that Alloy starts, only that the role restarts it once in converge and not in the idempotence run.

## Scenarios

| Scenario | Role under test                                                                                                        | Verify asserts                                                                                                                                                                                                                                               |
|----------|------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `motd`   | `configs-cloud/digital-ocean/ansible/roles/motd`                                                                       | `20-updates` output for update stamps with zero, one and several (the droplet's real stamp) pending updates, byte for byte; only `00-banner`, `10-os-line`, `20-updates` and `98-reboot-required` are executable; the `50-landscape-sysinfo` symlink is gone |
| `alloy`  | fleet role `configs-homelab/ansible/roles/grafana-cloud/alloy` with `alloy_fleet_extras: false` and the cloud template | no `github.token`, no capabilities on the Alloy binary, `config.alloy` has `environment = "digital-ocean"` and `stage = "prod"` in both `external_labels` blocks and no `github` or `remotecfg` block; Alloy was restarted exactly once                      |

The `alloy` scenario loads the droplet's `configs-cloud/digital-ocean/ansible/vars/main.yml` and sets the variables the droplet gets from the inventory and the vault in its converge playbook: `alloy_environment: digital-ocean`, `alloy_stage: prod` and fake Grafana Cloud secrets.

The `swap` role has no scenario. `swapon` cannot run in an unprivileged container, and a privileged one is not allowed (see above). The role is checked on the droplet: a second `task cloud:digital-ocean:ansible:provision` run reports no change.

## CI

The `molecule-cloud` job in `.github/workflows/pipeline.yml` runs the scenarios as a matrix (`motd`, `alloy`) after the linters, ShellCheck and the InSpec checks, next to the `molecule` job for the homelab roles. `generate-docs`, and through it the release, waits for both. See [Pipelines](../../pipelines.md).

## Adding a Role

A new role is not done without a scenario. For a new role under `configs-cloud/digital-ocean/ansible/roles`:

1. Add `<role>/molecule/default/molecule.yml`, `converge.yml` and `verify.yml` following the `motd` scenario.
2. Add a `test:<role>` task to `configs-cloud/digital-ocean/tests/molecule/taskfile.yml` and call it from `test`.
3. Add the role to the `molecule-cloud` matrix in `pipeline.yml`.
4. Put test-only setup in `prepare.yml` or the scenario's converge `pre_tasks`, never in the role. Never make the container privileged or mount host paths into it.
