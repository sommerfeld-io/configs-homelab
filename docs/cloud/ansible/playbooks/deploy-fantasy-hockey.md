# Ansible Playbook - Deploy Fantasy Hockey

This Ansible playbook runs the fantasy hockey app on the droplets with the tag `fantasy-hockey`. It needs a provisioned droplet.

- **Volume:** mounts the droplet's data volume at `/mnt/<droplet_name>_data`, or stops when the volume is not attached
- **Secrets:** loads the vault file `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml`
- **App:** runs the [Fantasy Hockey role](../roles/fantasy-hockey.md): the user `fantasy-hockey`, the deploy files on the volume and the docker compose stack (app and nginx on port 80)

Run it with `task cloud:digital-ocean:ansible:deploy-fantasy-hockey`. It asks for the vault password. `task cloud:digital-ocean:ansible:deploy-fantasy-hockey -- --tags volume` only mounts the volume. See [Deployment](../../digital-ocean/deployment.md) for the paths, the seed rule and the checks.
