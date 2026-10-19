# OpenTofu - DigitalOcean

This OpenTofu root module declares the DigitalOcean infrastructure: the droplets and, per droplet, an optional reserved IP and data volume, all assigned to the project `sommerfeld.io`. The state is kept locally in `terraform.tfstate` (gitignored). The provider reads its API token from `DIGITALOCEAN_ACCESS_TOKEN`.

Run it through go-task, e.g. `task cloud:digital-ocean:opentofu:plan`.

## Documentation

- [Overview](../../../docs/cloud/digital-ocean/index.md): what runs where on DigitalOcean
- [API Token](../../../docs/cloud/digital-ocean/api-token.md): token scopes and how `DIGITALOCEAN_ACCESS_TOKEN` reaches the shell
- [Tasks and Linters](../../../docs/cloud/digital-ocean/tasks-and-linters.md): the tasks of this module and the linters that check it
- [Droplet](../../../docs/cloud/digital-ocean/droplet.md): the files of this module, the droplet config options, reserved IPs and volumes
- [Replacement](../../../docs/cloud/digital-ocean/replacement.md): replacing a droplet without losing data or the address
