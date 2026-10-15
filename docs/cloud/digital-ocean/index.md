# Cloud - Digital Ocean

This section covers the production deployment on DigitalOcean that hosts the fantasy hockey app. It is separate from the homelab nodes: the configuration lives in `configs-cloud/digital-ocean/`, not in `configs-homelab/ansible/`, and the droplet is not part of the static inventory or the InSpec baseline.

All cloud resources are declared with OpenTofu and managed from this repository through go-task. `doctl` is used for read-only checks.

## What Runs Where

```kroki-plantuml
@startuml
skinparam componentStyle rectangle
skinparam defaultTextAlignment center

node "Operator workstation" as workstation {
  node "Devcontainer" as devcontainer {
    component "go-task\ncloud:*" as task
    component "OpenTofu\n(tofu)" as tofu
    component "doctl" as doctl
    component "Ansible\n(dynamic inventory)" as ansible
  }
  folder "Repo clone (bind-mounted)" as repo {
    database "Local state\nterraform.tfstate" as state
  }
}

cloud "Grafana Cloud" as grafana

cloud "DigitalOcean" as digitalocean {
  component "DigitalOcean API" as api

  frame "Project sommerfeld.io" as project {
    node "Droplet prod-fantasy-hockey\ns-1vcpu-1gb, fra1\ntags prod, fantasy-hockey\n(declared)" as droplet
    component "Reserved IP\n(declared)" as reservedip
    component "Grafana Alloy\n(swap file)" as alloy
    component "cAdvisor\n127.0.0.1:9110" as cadvisor
    component "fantasy-hockey stack\nCaddy :80, :443, app :8080\n(user fantasy-hockey)" as app
    storage "Volume 2 GB ext4\n/mnt/prod_fantasy_hockey_data\n(declared)" as volume
  }
}

task --> tofu : opentofu:init, fmt,\nplan, apply
task --> doctl : info
task --> ansible : ansible:inventory,\nansible:provision,\nansible:deploy-fantasy-hockey
ansible --> api : HTTPS\nDIGITALOCEAN_ACCESS_TOKEN
ansible --> droplet : SSH as root
tofu --> state : plan, apply:\nreads and writes
tofu --> api : HTTPS\nDIGITALOCEAN_ACCESS_TOKEN
doctl --> api : HTTPS\nDIGITALOCEAN_ACCESS_TOKEN
alloy --> grafana : metrics, logs\nenvironment, stage labels
api --> droplet : manages
api --> reservedip : manages
api --> volume : manages
reservedip ..> droplet : assigned to
volume ..> droplet : attached to
alloy ..> droplet : runs on
cadvisor ..> droplet : runs on
app ..> droplet : runs on
app --> volume : data file
alloy --> app : scrapes :8080/metrics
alloy --> cadvisor : scrapes :9110/metrics
reservedip --> app : HTTPS :443\nfantasy-hockey.prod.do.sommerfeld.app
@enduml
```

- **Operator workstation and devcontainer:** every step starts as a `task cloud:*` command from the repository root. The devcontainer provides `tofu`, `doctl` and `ansible` and receives the API token as `DIGITALOCEAN_ACCESS_TOKEN`.
- **OpenTofu:** declares the resources and records them in a local state file. The state file sits in the repo clone on the workstation (bind-mounted into the devcontainer) and is gitignored, so it survives a container rebuild but not the loss of the clone. It moves to a remote backend later.
- **Ansible:** finds droplets by tag through the DigitalOcean API and provisions them over SSH (basic command line tools, Docker, swap, cAdvisor, Alloy, login banner). See [Provisioning](provisioning.md).
- **Deployment:** `deploy-fantasy-hockey.yml` runs the fantasy hockey app (app and Caddy, docker compose) as the user `fantasy-hockey`, with its data and certificates on the volume, reachable over HTTPS at `https://fantasy-hockey.prod.do.sommerfeld.app` only. The reserved IP itself does not serve the app. See [Deployment](deployment.md).
- **Replacement:** a droplet is replaced (new image or broken droplet) while its volume and reserved IP stay. See [Replacement](replacement.md).
- **Domain:** `fantasy-hockey.prod.do.sommerfeld.app` points at the reserved IP through an A record kept by hand at all-inkl.com, outside OpenTofu. See [Domain](domain.md).
- **Grafana Cloud:** Alloy on the droplet ships metrics and logs with the labels `environment` and `stage`. The dashboard `Apps / Fantasy Hockey / Droplet` shows them, see [Monitoring](monitoring.md).
- **doctl:** prints the account and the droplets for a quick check.
- **DigitalOcean API:** OpenTofu and `doctl` manage DigitalOcean resources only through this API. No firewall, user-data scripts or managed database are used.

## Resources

All resources belong to the project `sommerfeld.io`.

| Resource    | Details                                                                                                                                                                                | Status   |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| Droplet     | [`prod-fantasy-hockey`](droplet.md), `s-1vcpu-1gb`, region fra1, Ubuntu 26.04 LTS x64, tag `prod`, DigitalOcean monitoring on, SSH key `picon___id_rsa.pub`                            | declared |
| Reserved IP | [Stable public address](droplet.md#reserved-ip-and-volume), survives droplet rebuilds, `prevent_destroy`                                                                               | declared |
| Volume      | [`prod-fantasy-hockey-data`](droplet.md#reserved-ip-and-volume), 2 GB, ext4, attached at creation and mounted at `/mnt/prod_fantasy_hockey_data`, survives rebuilds, `prevent_destroy` | declared |

The droplet is configured with Ansible. Ansible finds it through a [dynamic inventory](provisioning.md) by its tag.

## Pages

| Page                                      | Content                                                                        |
|-------------------------------------------|--------------------------------------------------------------------------------|
| [API Token](api-token.md)                 | Token scopes, how the token reaches the shell, manual steps and checks         |
| [Tasks and Linters](tasks-and-linters.md) | Folder layout, go-task entry points, OpenTofu state and linter coverage        |
| [Provisioning](provisioning.md)           | Dynamic inventory, groups, provision task and host key after a replacement     |
| [Droplet](droplet.md)                     | Droplet attributes, reserved IP and volume, droplet map, SSH keys, apply steps |
| [Domain](domain.md)                       | The app's DNS record at all-inkl.com, hostname pattern, manual steps and check |
| [Deployment](deployment.md)               | The fantasy hockey app: deploy playbook, user, paths, seed rule, Pi retirement |
| [Replacement](replacement.md)             | Replacing the droplet with its volume and reserved IP, checks and outage       |
| [Monitoring](monitoring.md)               | Grafana Cloud dashboard for the droplet, the app, the containers and the logs  |
| [Tests](tests.md)                         | Molecule scenarios for the roles the droplet runs                              |
