# Tasks and Linters

The DigitalOcean deployment lives in its own folder, separate from the homelab nodes:

```text
cloud-configs/
  taskfile.yml       # included in the root taskfile with prefix `cloud`
  digital-ocean/
    opentofu/        # droplet, reserved IP and volume
    ansible/         # dynamic inventory, playbooks and roles for the droplet (from Epic 3)
```

## Tasks

All steps run through go-task from the repository root. The tasks wrap `tofu` and `doctl` from the devcontainer; the OpenTofu tasks work on `cloud-configs/digital-ocean/opentofu`.

| Task                                      | What it does                                                   |
|-------------------------------------------|----------------------------------------------------------------|
| `task cloud:digital-ocean:opentofu:init`  | Initialize the OpenTofu working directory (providers, modules) |
| `task cloud:digital-ocean:opentofu:fmt`   | Format the OpenTofu files                                      |
| `task cloud:digital-ocean:opentofu:plan`  | Show the changes OpenTofu would make                           |
| `task cloud:digital-ocean:opentofu:apply` | Apply the OpenTofu configuration                               |
| `task cloud:digital-ocean:info`           | Print the account and all droplets with `doctl`                |

Run `init` once before `plan` and `apply`, and again after provider changes. `plan`, `apply` and `info` stop early when `DIGITALOCEAN_ACCESS_TOKEN` is not set. See [API Token](api-token.md).

There is no destroy task on purpose. The volume and reserved IP must survive droplet rebuilds.

OpenTofu state stays local in `cloud-configs/digital-ocean/opentofu/terraform.tfstate` for now and is not committed: `.terraform/`, `*.tfstate*` and `*.tfvars` are in `.gitignore`. The single local copy is an accepted risk until state moves to a remote backend in a later epic, so do not delete the working copy while resources exist. The OpenTofu version (`required_version`) and the `digitalocean/digitalocean` provider are pinned exactly in `versions.tf`. The provider lock file `.terraform.lock.hcl` is committed with hashes for every platform the provider is released for, as published by the OpenTofu registry. Dependabot (`opentofu` ecosystem) opens weekly pull requests that bump the provider pin and the lock file together.

## Linters

`task lint` and the `lint` job in the CI pipeline cover `cloud-configs` like the rest of the repository:

| Linter       | Coverage                                                                                                                                    |
|--------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| folderslint  | `cloud-configs/*/opentofu` and `cloud-configs/*/ansible/**` are allowed in `.folderslintrc`                                                 |
| ls-lint      | kebab-case filenames, including `.tf` files                                                                                                 |
| yamllint     | all YAML files, including `cloud-configs/taskfile.yml`                                                                                      |
| ansible-lint | `cloud-configs` is linted together with `ansible`                                                                                           |
| OpenTofu     | `tofu fmt -check -diff -recursive cloud-configs` (service `lint-opentofu`, keep the image version in sync with the devcontainer's OpenTofu) |

Run a single linter with `docker compose up lint-opentofu --exit-code-from lint-opentofu`. If the OpenTofu linter fails, run `task cloud:digital-ocean:opentofu:fmt` and commit the result.
