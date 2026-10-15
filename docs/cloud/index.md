# Cloud

Cloud deployments run in three steps, always in this order. Each step builds on the one before it and is safe to run again.

1. **Infrastructure (OpenTofu):** declares the cloud resources (droplet, reserved IP, volume) and creates or updates them through the provider API.
2. **Provisioning (Ansible):** configures every droplet the same way: base tools, Docker, swap, monitoring and login banner.
3. **App deployment (Ansible):** runs the apps on the droplets that carry the matching tag.

`task cloud:deploy:all` runs all three steps in one go. Each step also has its own task.

```kroki-plantuml
@startuml
start
if (DIGITALOCEAN_ACCESS_TOKEN set?) then (yes)
else (no)
  :Stop;
  note right: Hint to the API token docs
  stop
endif

partition "1. Infrastructure - OpenTofu" {
  :task cloud:digital-ocean:opentofu:apply;
  :Create or update resources;
  note right
    Droplet, reserved IP and volume
    State in local terraform.tfstate
  end note
}

partition "2. Provisioning - Ansible" {
  :Find droplets by tag;
  note right: Dynamic inventory
  :Wait for SSH and cloud-init;
  :Configure droplets;
  note right
    playbooks/provision.yml
    Base tools, Docker, swap,
    cAdvisor, Alloy and MOTD
  end note
}

partition "3. App deployment - Ansible" {
  :Mount the data volume;
  :Start the app stack;
  note right
    playbooks/deploy-*.yml
    docker compose
  end note
}

:App reachable at the reserved IP;
stop
@enduml
```

| Step              | Task                                                     | Details                                       |
|-------------------|----------------------------------------------------------|-----------------------------------------------|
| All steps         | `task cloud:deploy:all`                                  | Asks for the vault password once              |
| 1. Infrastructure | `task cloud:digital-ocean:opentofu:apply`                | [Droplet](digital-ocean/droplet.md)           |
| 2. Provisioning   | `task cloud:digital-ocean:ansible:provision`             | [Provisioning](digital-ocean/provisioning.md) |
| 3. App deployment | `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` | [Deployment](digital-ocean/deployment.md)     |
