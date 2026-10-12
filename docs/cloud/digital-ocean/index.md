# Cloud - Digital Ocean

This section covers the production deployment on DigitalOcean that hosts the fantasy hockey app. It is separate from the homelab nodes: the configuration lives in `cloud-configs/digital-ocean/`, not in `ansible/`, and the droplet is not part of the static inventory or the InSpec baseline.

All cloud resources are declared with OpenTofu and managed from this repository through go-task. `doctl` is used for read-only checks.

## What Runs Where

```kroki-plantuml
@startuml
skinparam componentStyle rectangle
skinparam defaultTextAlignment center

node "Operator workstation" as workstation {
  node "Devcontainer" as devcontainer {
    component "go-task\ncloud:digital-ocean:*" as task
    component "OpenTofu\n(tofu)" as tofu
    component "doctl" as doctl
  }
  folder "Repo clone (bind-mounted)" as repo {
    database "Local state\nterraform.tfstate" as state
  }
}

cloud "DigitalOcean" as digitalocean {
  component "DigitalOcean API" as api

  frame "Project sommerfeld.io" as project {
    node "Droplet prod-fantasy-hockey...\ns-1vcpu-1gb, fra1, tag prod\n(planned)" as droplet
    component "Reserved IP\n(planned)" as reservedip
    storage "Volume 2 GB ext4\n/mnt/<volume-name>\n(planned)" as volume
  }
}

task --> tofu : opentofu:init, fmt,\nplan, apply
task --> doctl : info
tofu --> state : plan, apply:\nreads and writes
tofu --> api : HTTPS\nDIGITALOCEAN_ACCESS_TOKEN
doctl --> api : HTTPS\nDIGITALOCEAN_ACCESS_TOKEN
api --> droplet : manages
api --> reservedip : manages
api --> volume : manages
reservedip ..> droplet : assigned to
volume ..> droplet : attached to
@enduml
```

- **Operator workstation and devcontainer:** every step starts as a `task cloud:digital-ocean:*` command from the repository root. The devcontainer provides `tofu` and `doctl` and receives the API token as `DIGITALOCEAN_ACCESS_TOKEN`.
- **OpenTofu:** declares the resources and records them in a local state file. The state file sits in the repo clone on the workstation (bind-mounted into the devcontainer) and is gitignored, so it survives a container rebuild but not the loss of the clone. It moves to a remote backend later.
- **doctl:** prints the account and the droplets for a quick check.
- **DigitalOcean API:** OpenTofu and `doctl` manage DigitalOcean resources only through this API. No firewall, user-data scripts or managed database are used.

## Resources

All resources belong to the project `sommerfeld.io`.

| Resource    | Details                                                                                                                            | Status  |
|-------------|------------------------------------------------------------------------------------------------------------------------------------|---------|
| Droplet     | Name starting with `prod-fantasy-hockey`, `s-1vcpu-1gb`, region fra1, Ubuntu 26.04 LTS x64, tag `prod`, DigitalOcean monitoring on | planned |
| Reserved IP | Stable public address, survives droplet rebuilds                                                                                   | planned |
| Volume      | 2 GB, ext4, attached at creation and mounted at `/mnt/<volume-name>`, survives rebuilds                                            | planned |

The droplet is configured with Ansible later. Ansible will find it through a dynamic inventory by its tag.

## Pages

| Page                                      | Content                                                                 |
|-------------------------------------------|-------------------------------------------------------------------------|
| [API Token](api-token.md)                 | Token scopes, how the token reaches the shell, manual steps and checks  |
| [Tasks and Linters](tasks-and-linters.md) | Folder layout, go-task entry points, OpenTofu state and linter coverage |
