# Temp Requirement Notes to feed to bmad (later)

## Taskfile

- Use `task: [cloud:info] doctl compute reserved-ip list` to create a ssh helper taskfile.
    - Add a taskfile-ssh-digital-ocean.yml next to configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml and roll out with configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml (as long as a node does not get a dedicated taskfile like raspi or caprica) and include the file in configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml. the goal is to generate ssh-connect command into the new taskfile-ssh-digital-ocean.yml for digital ocean that i  can use as `task digital-ocean:ssh:connect:<droplet-name>` with `digital-ocean` being the include-identifier.
    - Question: do i want to run this locally or from a github actions pipeline? this should be a story or epic towards the very end.

## Firewall

Lock the droplet in a way that only the app (or the proxy or nginx proxy manager) is reachable from the outside. Management UI should not be reachable publicly bt should be reachable for me. but first check if this is needed or if my app is protected enough. does a firewall cost me real-life money or is it free/included?

## Pipeline

Check with inspec or something if app is up-and-running.
Also check with inspec if the cloud vm is provisioned the way we want it to.
Bump versions in inspec yaml files on release.

Inpec Droplet
    Assert Timezone Europe/Berlin
    App up-and-running? ports listening? endpoints available?

## Versions

use dependabot do watch opentofu??
