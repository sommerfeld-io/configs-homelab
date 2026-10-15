# DigitalOcean API Token

All DigitalOcean steps (`doctl`, OpenTofu) authenticate with a personal access token exposed as the environment variable `DIGITALOCEAN_ACCESS_TOKEN`, which both tools read directly. The token is never committed in plain text.

## Token Scopes

Create the token as a custom-scoped personal access token in the DigitalOcean control panel (API > Tokens) with access to these resources:

| Scope         | Permissions                  | Needed for                                                                |
|---------------|------------------------------|---------------------------------------------------------------------------|
| droplet       | create, read, update, delete | create, read, update and delete the droplet                               |
| ssh_key       | read                         | look up the existing SSH key (data source, nothing is created or changed) |
| tag           | create, read                 | tag the droplet at creation (`tags = [...]`, stage plus extra tags)       |
| block_storage | create, read, update, delete | create and attach the 2 GB data volume                                    |
| reserved_ip   | create, read, update, delete | create and assign the reserved IP                                         |
| project       | create, read, update, delete | assign resources to the project                                           |
| actions       | read                         | read the status of long-running operations                                |

Creating a droplet also requires read access to regions, sizes, images, snapshots and VPCs (`regions:read`, `sizes:read`, `image:read`, `snapshot:read`, `vpc:read`), because the DigitalOcean API lists them as required scopes of `droplet:create`. The control panel groups scopes by resource, so tick the read scope of each of these as well. `tag:create` is only an optional "associated" scope of `droplet:create`, but DigitalOcean states that tagging a droplet during creation needs it; `tag:create` in turn requires `tag:read`. See [Scopes for API Tokens](https://docs.digitalocean.com/reference/api/scopes/) and [`droplet:create`](https://docs.digitalocean.com/reference/api/scopes/droplet/create/).

If the control panel names a scope differently, pick the one covering that resource. The permissions of the `block_storage`, `reserved_ip` and `project` scopes are the broad set used so far; trimming them was not verified.

`firewall` is not needed, because DigitalOcean firewalls are not used. `domain` is not needed, because DNS stays at all-inkl.com (see [Domain](domain.md)).

## How the Token Reaches the Shell

1. Add a `DIGITALOCEAN_TOKEN` entry to `configs-homelab/ansible/vars/vault.yml` (`task homelab:ansible:vault`). The vault key keeps this name; only the exported shell variable is called `DIGITALOCEAN_ACCESS_TOKEN`. The entry must exist before the `desktop` playbook runs, because the playbook references it.
2. Provision the workstation with the `desktop` playbook. It writes `export DIGITALOCEAN_ACCESS_TOKEN=...` to the default user's `.bashrc` through `configs-homelab/ansible/tasks/bash-secrets.yml`.
3. Open a new shell on the workstation. The variable is now exported.
4. The devcontainer sets `DIGITALOCEAN_ACCESS_TOKEN` from the host environment through `containerEnv`, so start VS Code from a shell where it is set, then rebuild the devcontainer.

## Manual Steps

- Create the token in the DigitalOcean control panel with the scopes above. This is a permanently manual step.
- Add the token to the vault (step 1 above) and re-run the `desktop` playbook.
- Rebuild the devcontainer after the first run so `doctl` and `tofu` are installed and the token is picked up.

## Verify

```bash
doctl version
tofu version
doctl account get   # fails with 401 if the token is missing or invalid
```

If `doctl` reports an unauthorized error inside the devcontainer, the variable was probably empty when the container started (VS Code launched from a desktop launcher does not read `.bashrc`). Check `echo "${DIGITALOCEAN_ACCESS_TOKEN:+set}"`, start VS Code from a shell where the token is set, and rebuild the container.

## Tool Versions

The devcontainer installs pinned versions of `doctl` and OpenTofu through devcontainer features. The versions are set in `.devcontainer/devcontainer.json`. OpenTofu is pinned exactly (`1.12.7`), matching `required_version` in `versions.tf` and the `lint-opentofu` image; `tofu init` and `plan` refuse any other version.

The devcontainer is the supported way to run `tofu`. The host install (snap or pacman via the `packages` role) is an unpinned safety net only; if it ships a different OpenTofu version, use the devcontainer.
