# DigitalOcean API Token

All DigitalOcean steps (`doctl`, OpenTofu) authenticate with a personal access token exposed as the environment variable `DIGITALOCEAN_ACCESS_TOKEN`, which both tools read directly. The token is never committed in plain text.

## Token Scopes

Create the token as a custom-scoped personal access token in the DigitalOcean control panel (API > Tokens) with access to these resources:

| Scope         | Needed for                                  |
|---------------|---------------------------------------------|
| droplet       | create, read, update and delete the droplet |
| ssh_key       | read and manage the SSH keys of the account |
| block_storage | create and attach the 2 GB data volume      |
| reserved_ip   | create and assign the reserved IP           |
| project       | assign resources to the project             |
| actions       | read the status of long-running operations  |

Grant the create, read, update and delete permissions for each scope. If the control panel names a scope differently, pick the one covering that resource.

Add `firewall` or `domain` only if a later story needs them. DigitalOcean firewalls are not used.

## How the Token Reaches the Shell

1. Add a `DIGITALOCEAN_TOKEN` entry to `configs-homelab/ansible/vars/vault.yml` (`task ansible:vault`). The vault key keeps this name; only the exported shell variable is called `DIGITALOCEAN_ACCESS_TOKEN`. The entry must exist before the `desktop` playbook runs, because the playbook references it.
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

The devcontainer installs pinned versions of `doctl` and OpenTofu (the 1.12.x line) through devcontainer features. The versions are set in `.devcontainer/devcontainer.json`.
