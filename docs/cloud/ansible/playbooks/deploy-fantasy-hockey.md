# Ansible Playbook - Deploy Fantasy Hockey

This Ansible playbook runs the fantasy hockey app on the droplets with the tag `fantasy-hockey`. It needs a provisioned droplet.

- **Volume:** mounts the droplet's data volume at `/mnt/<droplet_name>_data`, or stops when the volume is not attached, and adds a `docker.service` drop-in (`RequiresMountsFor=`) so Docker starts only after the volume is mounted
- **Secrets:** loads the vault file `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml`
- **Domain:** derives `fantasy_hockey_domain` (`<app>.<stage>.do.sommerfeld.app`) from the droplet name and reads the droplet's reserved IP from the DigitalOcean metadata service, or stops when it has none
- **App:** runs the [Fantasy Hockey role](../roles/fantasy-hockey.md): the user `fantasy-hockey`, the deploy files on the volume and the docker compose stack (app and Caddy on ports 80 and 443, HTTPS at the domain). The role stops before writing anything when the domain does not resolve to the reserved IP

Run it with `task cloud:digital-ocean:ansible:deploy-fantasy-hockey`. It asks for the vault password. `task cloud:digital-ocean:ansible:deploy-fantasy-hockey -- --tags volume` only mounts the volume. See [Deployment](../../digital-ocean/deployment.md) for the paths, the seed rule and the checks.
