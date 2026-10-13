# Tasks and Linters

The DigitalOcean deployment lives in its own folder, separate from the homelab nodes:

```text
configs-cloud/
  taskfile.yml       # included in the root taskfile with prefix `cloud`
  digital-ocean/
    opentofu/        # droplet, reserved IP and volume
    ansible/         # dynamic inventory, playbooks, cloud roles and vars for the droplet
    tests/molecule/  # one Molecule scenario per role the droplet runs, see Tests
```

## Tasks

All steps run through go-task from the repository root. The tasks wrap `tofu` and `doctl` from the devcontainer; the OpenTofu tasks work on `configs-cloud/digital-ocean/opentofu`.

| Task                                         | What it does                                                                                                         |
|----------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `task cloud:digital-ocean:opentofu:init`     | Initialize the OpenTofu working directory (providers, modules)                                                       |
| `task cloud:digital-ocean:opentofu:fmt`      | Format the OpenTofu files                                                                                            |
| `task cloud:digital-ocean:opentofu:plan`     | Show the changes OpenTofu would make                                                                                 |
| `task cloud:digital-ocean:opentofu:apply`    | Apply the OpenTofu configuration                                                                                     |
| `task cloud:digital-ocean:ansible:inventory` | List the droplets found by the dynamic inventory with their groups                                                   |
| `task cloud:digital-ocean:ansible:provision` | Provision all Ubuntu droplets with Ansible (prompt, Docker, swap, Alloy, MOTD), after waiting for SSH and cloud-init |
| `task cloud:digital-ocean:deploy`            | Full pipeline: `opentofu:apply`, then `ansible:provision`                                                            |
| `task cloud:info`                            | Print the account and all droplets with `doctl`                                                                      |
| `task molecule-cloud:test`                   | Run every Molecule scenario for the roles the droplet runs ([Tests](tests.md))                                       |
| `task molecule-cloud:test:<role>`            | Run one Molecule scenario: `motd` or `alloy`                                                                         |

Run `init` once before `plan` and `apply`, and again after provider changes. The OpenTofu and Ansible tasks that need the token and `info` stop early when `DIGITALOCEAN_ACCESS_TOKEN` is not set. See [API Token](api-token.md).

There is no destroy task on purpose. The volume and reserved IP must survive droplet rebuilds, so both have `lifecycle { prevent_destroy = true }` and OpenTofu refuses any plan that would destroy them, including `tofu plan -destroy`, with `Resource instance cannot be destroyed`. The droplet itself stays replaceable.

OpenTofu state stays local in `configs-cloud/digital-ocean/opentofu/terraform.tfstate` for now and is not committed: `.terraform/`, `*.tfstate*` and `*.tfvars` are in `.gitignore`. The single local copy is an accepted risk until state moves to a remote backend in a later epic, so do not delete the working copy while resources exist. The OpenTofu version (`required_version`) and the `digitalocean/digitalocean` provider are pinned exactly in `versions.tf`. The provider lock file `.terraform.lock.hcl` is committed with hashes for every platform the provider is released for, as published by the OpenTofu registry. Dependabot (`opentofu` ecosystem) opens weekly pull requests that bump the provider pin and the lock file together.

## Linters

`task lint` and the `lint` job in the CI pipeline cover `configs-cloud` like the rest of the repository:

| Linter       | Coverage                                                                                                                                                                                                                                                                                             |
|--------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| folderslint  | `configs-cloud/*/opentofu`, `configs-cloud/*/ansible` and its `inventory`, `playbooks`, `vars`, `templates/*` and `roles` folders, `defaults`, `files`, `handlers`, `tasks` and `templates` inside each role, and everything under `configs-cloud/*/tests/molecule`, are allowed in `.folderslintrc` |
| ls-lint      | kebab-case filenames, including `.tf` files                                                                                                                                                                                                                                                          |
| yamllint     | all YAML files, including `configs-cloud/taskfile.yml`                                                                                                                                                                                                                                               |
| ansible-lint | `configs-cloud` is linted together with `configs-homelab/ansible`, except `playbooks/provision.yml`: it loads the vaulted `grafana-vault.yml`, so it is in `exclude_paths` of `.ansible-lint.yml` like the fleet playbooks. The Molecule playbooks under `tests/molecule` are linted too             |
| OpenTofu     | `tofu fmt -check -diff -recursive configs-cloud` (service `lint-opentofu`, keep the image version in sync with the devcontainer's OpenTofu)                                                                                                                                                          |

Before the linters run, `task lint` formats the OpenTofu code with `task cloud:digital-ocean:opentofu:fmt`. The `lint-repo` pre-commit hook runs `task lint`, so OpenTofu files are formatted on every commit and only formatted code reaches the remote repository, which avoids conflicting whitespace changes. Only the OpenTofu code is formatted; all other files are only linted. Locally, the OpenTofu linter therefore checks freshly formatted files; stage the files the hook reformatted and commit again.

Run a single linter with `docker compose up lint-opentofu --exit-code-from lint-opentofu`. CI runs the linters without formatting first, so if the OpenTofu linter fails there, run `task cloud:digital-ocean:opentofu:fmt` and commit the result.
