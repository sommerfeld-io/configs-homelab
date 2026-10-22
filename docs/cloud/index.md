# Cloud

Cloud deployments run in three steps, always in this order. Each step builds on the one before it and is safe to run again.

1. **Infrastructure (OpenTofu):** declares the cloud resources (droplet, reserved IP, volume, DNS zone and records) and creates or updates them through the provider API.
2. **Provisioning (Ansible):** configures every droplet the same way: base tools, Docker, swap, monitoring and login banner.
3. **App deployment (Ansible):** runs the apps on the droplets that carry the matching tag.

`task cloud:deploy:all` runs all three steps in one go. Each step also has its own task.

The app deployment stops unless the app's domain resolves to the droplet's reserved IP. Step 1 creates the reserved IP and the app's DNS record together (in the delegated zone `do.sommerfeld.app`, see [DNS Zone](digital-ocean/dns-zone.md)), so a new droplet passes `deploy:all` in one go. Only a resolver that asked for the name before the record existed caches the NXDOMAIN for up to 1800 s; then wait and run the app deployment again (see [Domain](digital-ocean/domain.md#check)). A replacement keeps the reserved IP and its record.

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
    Droplet, reserved IP, volume
    and DNS records
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
    note right: Wait for the DNS record, deploy again
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
