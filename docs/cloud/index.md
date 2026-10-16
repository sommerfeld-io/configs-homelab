# Cloud

Cloud deployments run in three steps, always in this order. Each step builds on the one before it and is safe to run again.

1. **Infrastructure (OpenTofu):** declares the cloud resources (droplet, reserved IP, volume) and creates or updates them through the provider API.
2. **Provisioning (Ansible):** configures every droplet the same way: base tools, Docker, swap, monitoring and login banner.
3. **App deployment (Ansible):** runs the apps on the droplets that carry the matching tag.

`task cloud:deploy:all` runs all three steps in one go. Each step also has its own task.

A new droplet that runs an app cannot pass its first `deploy:all`: steps 1 and 2 succeed, but the app deployment stops unless the app's domain resolves to the droplet's reserved IP, and that IP exists only after step 1. Its DNS record is created by hand in between. So run step 1 alone (`task cloud:digital-ocean:opentofu:apply`), create the record, wait until public resolvers and the droplet return the reserved IP, then run `deploy:all`. See [Domain](digital-ocean/domain.md#check) for the steps. A replacement keeps the reserved IP and its record, so `deploy:all` works in one go there.

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
  if (Domain resolves to exactly the reserved IP?) then (yes)
  else (no)
    :Stop before anything is written;
    note right: New droplet: create the DNS record first
    stop
  endif
  :Start the app stack;
  note right
    playbooks/deploy-*.yml
    docker compose
  end note
}

:App reachable over HTTPS at its domain;
stop
@enduml
```

| Step              | Task                                                     | Details                                       |
|-------------------|----------------------------------------------------------|-----------------------------------------------|
| All steps         | `task cloud:deploy:all`                                  | Asks for the vault password once              |
| 1. Infrastructure | `task cloud:digital-ocean:opentofu:apply`                | [Droplet](digital-ocean/droplet.md)           |
| 2. Provisioning   | `task cloud:digital-ocean:ansible:provision`             | [Provisioning](digital-ocean/provisioning.md) |
| 3. App deployment | `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` | [Deployment](digital-ocean/deployment.md)     |
