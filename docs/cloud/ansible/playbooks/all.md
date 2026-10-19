# Ansible Playbook - All

This Ansible playbook sets up every DigitalOcean droplet in one run. It imports the other cloud playbooks in this order:

- [Provision the droplets](./provision.md) (all Ubuntu droplets)
- [Deploy the fantasy hockey app](./deploy-fantasy-hockey.md) (droplets with the tag `fantasy-hockey`)

Run it with `task cloud:digital-ocean:ansible:all`. It asks for the vault password once. `task cloud:deploy:all` runs OpenTofu first and then this playbook, see [Tasks and Linters](../../digital-ocean/tasks-and-linters.md).
