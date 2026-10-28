# Temp Requirement Notes to feed to bmad (later)

## Pipeline

Think about and refine "6.3 Cloud deployment.yml with org secrets and a CI SSH key"
Do i want a decicated cloud-deployment.yml or should this be part of pipeline.yml and release.yml?
Brainstorm and update?

The OpenTofu for grafana cloud should also be its own github actions workflow and should deploy opentofu changes to grafana cloud.

all workflows for cloud deployments should be named "Cloud Deploy: <type>" (e.g. "Cloud Deploy: Applications" for all app deployments or "Cloud Deploy: Grafana Cloud")

Can dependabot commit with "feat:" prefix for fantasy-hockey updates? If so, the cloud deployments can be part of the release.yml and do not need a different pipeline with a dedicated trigger.

but do i want this? because then, all unrelated features would also trigger cloud deployments. but since I do not change anything manually, this should not cause any harm and should instead avoid configuration drift.

otherwise, a dedicated pipeline should run only when cloud-configs or grafana-cloud changes. and pipeline.yml should not be triggered on these changes.

Merging lots of dependabot PRs in the repo in quick succession would result in lots of pipeline runs that all would provision infrastructore omn digitalocean. even though they would not change anything (most likely), they are still obsolete. So maybe this is a point for a dedicated workflow? if so, the workflow would need linting and validation etc. too. but i would like to not duplicate this steps.

### Pipeline Testss

Check with inspec or something if app is up-and-running.
Also check with inspec if the cloud vm is provisioned the way we want it to.
Bump versions in inspec yaml files on release.

Inpec Droplet
    Assert Timezone Europe/Berlin
    App up-and-running? ports listening? endpoints available?

## Taskfile

- Use `task: [cloud:info] doctl compute reserved-ip list` to create a ssh helper taskfile.
    - Add a taskfile-ssh-digital-ocean.yml next to configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml and roll out with configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml (as long as a node does not get a dedicated taskfile like raspi or caprica) and include the file in configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml. the goal is to generate ssh-connect command into the new taskfile-ssh-digital-ocean.yml for digital ocean that i  can use as `task digital-ocean:ssh:connect:<droplet-name>` with `digital-ocean` being the include-identifier.
    - Question: do i want to run this locally or from a github actions pipeline? this should be a story or epic towards the very end.

## Grafana / Logging

- fantasy-hockey
    - App should log all outputs to (all log levels and all output streams) as JSON. Do not implement this on your own. Use some logging library
- configs-homelab
    - Alloy should parse caddy logs which are JSON (container = fantasy-hockey-caddy). Alloy should parse app logs which are JSON (container = fantasy-hockey-app).
- Grafana Cloud AI
    - Update dashboard for fantasy hockey app to show all relevant information from the json logs in diagrams.
    - This one needs some more details before prompting

## Firewall

Lock the droplet in a way that only the app (or the proxy or nginx proxy manager) is reachable from the outside. Management UI should not be reachable publicly bt should be reachable for me. but first check if this is needed or if my app is protected enough. does a firewall cost me real-life money or is it free/included?

## Versions

use dependabot do watch opentofu??

## Reveal JS

Architecture of the repo and the homelab and cloud and pipeline setup etc. as RevealJS presentation? As part of the docs page?
