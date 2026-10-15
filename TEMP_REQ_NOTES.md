# Temp Requirement Notes to feed to bmad (later)

## nginx proxy manager

instead of a traditional nginx reverse proxy ...
create issue for this

## Taskfile

- Use `task: [cloud:info] doctl compute reserved-ip list` to create a ssh helper taskfile.
    - Add a taskfile-ssh-digital-ocean.yml next to configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml and roll out with configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml (as long as a node does not get a dedicated taskfile like raspi or caprica) and include the file in configs-homelab/ansible/roles/common/taskfile-dev/files/taskfile.yml. the goal is to generate ssh-connect command into the new taskfile-ssh-digital-ocean.yml for digital ocean that i  can use as `task digital-ocean:ssh:connect:<droplet-name>` with `digital-ocean` being the include-identifier.
    - Question: do i want to run this locally or from a github actions pipeline? this should be a story or epic towards the very end.

## Firewall

Lock the droplet in a way that only the app (or the proxy or nginx proxy manager) is reachable from the outside. Management UI should not be reachable publicly bt should be reachable for me.

## Monitoring

```markdown
# Create a BMAD Story: Extend Fantasy Hockey Droplet Monitoring

Add this as a story to epic 5 as story 5.3.

## Objective

Create a BMAD story for extending the monitoring of the Fantasy Hockey application and its DigitalOcean droplet using Grafana Cloud and Grafana Alloy.

The story must cover the collection, shipping, visualization, and monitoring of:

1. Caddy access logs.
2. Caddy operational logs.
3. Caddy certificate lifecycle activity.
4. Let's Encrypt certificate validity and expiration.
5. The application's `/monitoring` endpoint.

All relevant data must be integrated into the existing Grafana dashboard definition:

`grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json`

The goal is to make the dashboard the central place for monitoring the droplet, reverse proxy, HTTPS certificates, and application health.

**Do not implement the changes yet. Create the BMAD story only.**

## 1. Inspect the existing repository

Before creating the story, inspect the repository and identify the existing implementation and conventions.

At minimum, investigate:

- The current Caddy deployment and configuration, including Docker Compose files, volumes, networks, and logging configuration.
- The existing Grafana Alloy deployment and configuration.
- How Alloy collects and forwards logs, metrics, and other telemetry to Grafana Cloud.
- Existing Grafana Cloud integrations, data sources, credentials handling, and configuration conventions.
- The existing dashboard at `grafana-cloud/manifests/git-sync/apps/fantasy-hockey-droplet.json`.
- How dashboards are provisioned, version-controlled, and synchronized with Grafana Cloud.
- The Fantasy Hockey application's `/monitoring` endpoint, including its response format, exposed metrics, and current scraping configuration.
- Existing certificate monitoring, exporters, Prometheus scrape jobs, alerting rules, and certificate-related dashboard panels.
- Existing BMAD story templates, naming conventions, workflows, and acceptance-criteria conventions.
- Existing documentation conventions, including the use of PlantUML diagrams.

Search the repository rather than assuming that the above functionality is missing. Distinguish between functionality that already exists, functionality that needs modification, and genuinely missing functionality.

The story must avoid duplicate collection pipelines, duplicate dashboard panels, and redundant exporters or monitoring components.

## 2. Caddy log collection

The story must specify how to collect and ship the following Caddy logs to Grafana Cloud using the existing Grafana Alloy setup.

### 2.1 Access logs

Collect HTTP access logs from Caddy.

The implementation must preserve useful structured fields wherever available, including:

- Timestamp.
- Request method.
- Request URI or path.
- Hostname.
- HTTP status code.
- Request duration.
- Response size.
- Client information, subject to privacy considerations.
- Upstream or reverse-proxy information, where available.

Use structured JSON logging where appropriate.

Access logs must be queryable in Grafana Cloud, preferably through Loki, and usable for dashboard panels and troubleshooting.

Investigate whether access logging is already enabled. If not, the story must specify the necessary configuration changes.

### 2.2 Operational logs

Collect Caddy's operational logs, including relevant information about:

- Startup and shutdown.
- Configuration loading and reloading.
- Listener and network errors.
- Reverse-proxy failures.
- Runtime errors and warnings.
- Other useful operational events.

Ensure operational logs can be distinguished from HTTP access logs using appropriate labels or parsed fields.

### 2.3 Certificate lifecycle activity

Collect Caddy log events related to certificate management, including where available:

- Certificate acquisition.
- Successful certificate issuance.
- Renewal attempts.
- Successful renewals.
- Renewal failures.
- Certificate loading and storage errors.
- Other relevant TLS and certificate-management errors.

Investigate how Caddy actually reports these events in the deployed version. Do not assume that every event is emitted at a particular log level or that every lifecycle event is guaranteed to appear in the logs.

Specify any necessary logging configuration changes.

### 2.4 Log pipeline requirements

The story must explain how logs flow from Caddy through Alloy to Grafana Cloud.

Requirements:

- Reuse the existing Alloy deployment and Grafana Cloud integration.
- Follow existing repository conventions
```

## Pipeline

Check with inspec or something if app is up-and-running.
Also check with inspec if the cloud vm is provisioned the way we want it to.
Bump versions in inspec yaml files on release.

Inpec Droplet
    Assert Timezone Europe/Berlin

## Ansible

create a user for the app on the droplet to avoid running it as root

## Versions

use dependabot do watch opentofu??

---

```markdown
# Create a BMAD Refactoring Story: Manage DigitalOcean DNS with OpenTofu

## Objective

Create a BMAD refactoring story for this repository to migrate the management of DigitalOcean-related DNS records from ALL-INKL to DigitalOcean DNS, managed declaratively through OpenTofu.

The goal is to manage DNS records as infrastructure as code, so that hostname-to-IP mappings can be changed reliably and reproducibly whenever an application or Droplet changes its IP address.

An existing example is:

- Hostname: `fantasy-hockey.prod.do.sommerfeld.app`
- DNS provider currently managing the A record: ALL-INKL KAS
- Target infrastructure: DigitalOcean
- Desired DNS management: DigitalOcean DNS, managed through OpenTofu

The `do` label identifies the DigitalOcean-related namespace in `sommerfeld.app`.

Ideally, **all subdomains of `do.sommerfeld.app` should be managed by DigitalOcean DNS**, rather than maintaining individual application records in ALL-INKL. Investigate the feasibility and recommend the cleanest DNS delegation architecture that achieves this without unnecessarily migrating unrelated DNS records.

## Important instructions

- Inspect the repository before proposing changes.
- Follow the repository's existing conventions for BMAD stories, story templates, acceptance criteria, documentation, OpenTofu modules, environments, variables, and naming.
- This task is to create a story, not to implement the refactoring itself.
- Do not modify production infrastructure or apply any OpenTofu changes.
- Do not create fictitious resource names, repository paths, existing architecture details, or completed migration steps.
- Distinguish clearly between actions that can be automated through OpenTofu and actions that require my manual intervention.
- If a requirement cannot be verified from the repository, identify it as an open question or investigation task.
- Prefer a maintainable, reusable solution over a one-off implementation for the fantasy-hockey application.
- Keep the story independently understandable and actionable by a future implementation agent.

## 1. Inspect the existing repository

Before creating the story, investigate the existing implementation and identify:

- Where OpenTofu configurations and DigitalOcean resources are defined.
- How DigitalOcean provider authentication and secrets are currently configured.
- How Droplet IP addresses are obtained and exposed.
- Whether applications already have hostname-to-IP mappings, DNS variables, outputs, or configuration files.
- Whether the repository contains existing DNS zones, DNS records, or domain resources.
- How environments such as development, test, staging, and production are separated.
- Whether application deployments or other automation currently depend on DNS records managed through ALL-INKL.
- How BMAD stories are structured, named, linked, and stored.
- Where infrastructure and operational documentation belongs.
- Whether PlantUML is already used and how diagrams are integrated into documentation.

Use the findings to write a story that references actual repository paths, resources, modules, and conventions wherever possible.

## 2. Investigate the target DNS architecture

Evaluate how to manage `do.sommerfeld.app` through DigitalOcean DNS.

The preferred architecture is:

1. Keep the registration of `sommerfeld.app` with its existing registrar unless there is a compelling reason to change it.
2. Keep the existing authoritative DNS provider for `sommerfeld.app` and unrelated records unchanged.
3. Delegate `do.sommerfeld.app` to DigitalOcean DNS using NS records in the parent zone, managed by the current authoritative DNS provider.
4. Manage the delegated `do.sommerfeld.app` zone and its application records through OpenTofu and the DigitalOcean provider.
5. Make hostname-to-IP mappings configurable so that changing a Droplet's IP address does not require manually editing DNS records in the DigitalOcean control panel.

Investigate whether this delegation model is supported by the existing setup and identify any limitations or prerequisites.

In particular:

- Determine whether ALL-INKL KAS supports the required NS records and delegation configuration.
- Verify the appropriate DigitalOcean nameservers and delegation requirements from authoritative documentation.
- Determine how the delegated zone should be represented in OpenTofu.
- Investigate whether the existing DNS zone or individual records need to be imported into OpenTofu state.
- Identify DNS propagation, caching, TTL, and migration considerations.
- Identify possible conflicts with existing records and DNSSEC configuration.
- Consider whether any existing wildcard records or application-specific records need to be preserved.
- Explain how unrelated records in `sommerfeld.app` will remain unaffected.
- Establish whether `do.sommerfeld.app` should contain only DigitalOcean-hosted applications or whether additional use cases need consideration.

Do not assume that creating a DNS zone in DigitalOcean automatically transfers DNS authority to DigitalOcean.

If full delegation is not feasible, document the alternatives, their trade-offs, and the recommended fallback architecture.

## 3. Define dynamic hostname-to-IP management

The refactoring should eliminate unnecessary hard-coded IP addresses in DNS resource definitions wherever possible.

Investigate the existing repository and select the most appropriate implementation.

Consider the following approaches:

- Reference a DigitalOcean Droplet's IP address directly from its OpenTofu resource.
- Reference a reusable module's output when the Droplet is defined in another module.
- Use a configurable hostname-to-IP mapping when the application points to infrastructure managed outside the current OpenTofu configuration.
- Use an appropriate combination of these approaches for different deployment scenarios.

The story must define how to support at least the following cases:

1. A Droplet is recreated and receives a different public IPv4 address.
2. An application is moved to a different Droplet.
3. A hostname must point to an externally managed IP address.
4. An application is added or removed.
5. Multiple hostnames point to the same Droplet.
6. The same application is deployed into multiple environments.

Investigate whether an existing static IP or reserved IP resource is appropriate for relevant DigitalOcean workloads. Do not introduce additional infrastructure without explaining why it is necessary.

The story must establish:

- Where hostname-to-IP mappings are configured.
- How OpenTofu resolves the target IP address.
- How DNS records are created, updated, and removed.
- How changes are reviewed before being applied.
- How to avoid unnecessary DNS changes when the target IP has not changed.
- How secrets and credentials are handled.
- How dependencies between Droplets, modules, and DNS records are represented.

Prefer references to resource attributes and module outputs over duplicated IP values.

Do not store sensitive information in DNS configuration or commit API tokens to the repository.

## 4. Define migration and operational safety

The story must explicitly address migration from the current ALL-INKL A record to the new delegated DNS architecture.

Create a step-by-step migration plan covering:

1. Inventory all existing records relevant to `do.sommerfeld.app`.
2. Determine the current authoritative nameservers and DNS configuration.
3. Record the current hostname-to-IP mappings and relevant TTL values.
4. Identify any existing records that must be preserved.
5. Create and validate the DigitalOcean DNS zone.
6. Configure the required NS delegation in the parent zone at ALL-INKL.
7. Import existing resources into OpenTofu state where appropriate.
8. Validate the delegated zone and individual records before removing obsolete records.
9. Verify DNS resolution using authoritative nameserver queries and independent resolvers.
10. Confirm that the application remains reachable over HTTPS.
11. Remove obsolete DNS configuration only after the new setup is verified.
12. Document rollback procedures and recovery options.

Adapt the sequence to the verified existing architecture. Do not blindly follow the sequence if DNS delegation or state management requires a different order.

Explicitly distinguish between:

- Changes that can be implemented and reviewed through OpenTofu.
- Changes that require manual actions in the ALL-INKL KAS interface.
- Changes that require manual verification.
- Changes that require coordination with a registrar or another DNS provider.
- Actions that are safe to repeat and actions that could cause downtime or destroy resources.

The story must never assume that an OpenTofu plan or apply alone completes the entire migration.

Include clear safeguards against accidental DNS record deletion, unexpected resource replacement, and loss of unrelated DNS records.

## 5. Create comprehensive documentation

The story must require updating or creating documentation in the repository's established documentation structure.

At minimum, document:

- The DNS architecture and delegation model.
- The responsibility of ALL-INKL versus DigitalOcean.
- How `do.sommerfeld.app` is delegated.
- How DNS zones and records are managed through OpenTofu.
- How hostname-to-IP mappings are configured.
- How to add a new application hostname.
- How to update an application's target IP.
- How to remove an application hostname safely.
- How to handle a recreated Droplet or a migration to a different Droplet.
- How to initialize, plan, review, and apply the relevant OpenTofu configuration.
- How to import existing DNS resources into state when necessary.
- How to validate DNS resolution and troubleshoot common issues.
- How to recover from an incorrect DNS change.
- Which steps still require manual intervention in ALL-INKL KAS.
- Which operations are automated and which are not.

Use the existing documentation conventions and navigation structure. Update the relevant index or navigation configuration if required.

Avoid documenting secrets or relying on undocumented assumptions.

## 6. Include PlantUML diagrams

The documentation must include PlantUML diagrams that improve understanding of the architecture and operational workflows.

At minimum, include the following diagrams, using the diagram types best suited to each purpose.

### A. DNS architecture diagram

Show:

- The domain registrar, if relevant to the actual architecture.
- ALL-INKL as the authoritative provider for the parent zone.
- The `do.sommerfeld.app` delegation through NS records.
- DigitalOcean as the authoritative provider for the delegated zone.
- OpenTofu as the mechanism for managing DigitalOcean DNS resources.
- Application hostnames and their corresponding DigitalOcean Droplets.
- The DNS resolution path from a client to the application endpoint.

Make clear which provider is authoritative for each zone.

### B. DNS record update sequence diagram

Show the sequence of events when a Droplet's public IP changes and OpenTofu updates the corresponding DNS record.

Include the relevant actors, such as:

- The operator or deployment pipeline.
- OpenTofu.
- The DigitalOcean API.
- The Droplet.
- DigitalOcean DNS.
- DNS resolvers and application clients.

Distinguish between infrastructure changes, DNS updates, and the subsequent effects of DNS caching and propagation.

### C. Migration sequence diagram

Show the migration from the existing ALL-INKL-managed A record to DigitalOcean-managed DNS, including:

- Inventory and preparation.
- Creation and validation of the delegated zone.
- NS delegation at ALL-INKL.
- OpenTofu state import, if required.
- DNS verification.
- Application and HTTPS verification.
- Removal of obsolete configuration.
- Rollback or recovery if validation fails.

Represent manual actions explicitly in the diagrams, for example through a dedicated operator actor or clearly labelled steps.

Use valid PlantUML syntax and follow the repository's existing PlantUML conventions. Prefer source diagrams committed alongside the documentation so that they can be maintained and regenerated.

## 7. Specify acceptance criteria

Create testable acceptance criteria in the BMAD story format required by the repository.

The criteria must cover at least:

- The delegated DNS zone is represented in OpenTofu.
- DNS records are managed declaratively rather than manually in the DigitalOcean control panel.
- A hostname can be associated with a Droplet's IP through a resource reference or an appropriate configuration mapping.
- Changing the target IP results in the expected DNS record change.
- Unchanged IP mappings do not cause unnecessary resource changes.
- Existing records are migrated or imported without accidental duplication or destruction.
- Unrelated records in the parent zone remain unaffected.
- A new application hostname can be added using the documented procedure.
- DNS resolution can be verified against authoritative nameservers.
- HTTPS and application reachability are verified after migration.
- The migration and rollback procedures are documented.
- Every manual step is explicitly identified.
- PlantUML diagrams are present, valid, and linked from the documentation.
- Documentation navigation is updated where necessary.
- The implementation can be validated with an OpenTofu plan without applying changes to production.

Adjust these criteria to the repository's established testing and acceptance conventions.

## 8. Define testing and validation requirements

The story must require suitable validation, such as:

- OpenTofu formatting and validation.
- Provider and module consistency checks.
- A plan review for DNS record creation, updates, deletion, and resource replacement.
- Appropriate static analysis or linting already used by the repository.
- DNS syntax and record consistency checks.
- PlantUML diagram validation where tooling is available.
- Verification of the migration and rollback instructions.

Identify which checks can be performed automatically and which require manual testing.

Do not claim that live DNS resolution, external HTTPS connectivity, or successful migration has been verified unless it actually has been tested.

## 9. Deliverable: the BMAD story

Create the story in the correct location using the repository's existing BMAD structure and naming conventions.

The story should include:

1. A clear title and summary.
2. The business and technical motivation.
3. The current state, based on repository inspection.
4. The desired state and architecture.
5. The proposed implementation approach.
6. Scope and explicit out-of-scope items.
7. Detailed implementation tasks and subtasks.
8. Testable acceptance criteria.
9. Documentation and PlantUML requirements.
10. Migration and rollback instructions.
11. A dedicated, ordered checklist of all manual tasks I must perform.
12. Dependencies, risks, assumptions, and unresolved questions.
13. Relevant repository paths and references to existing resources.
14. Completion and verification criteria.

The manual task checklist must be particularly detailed. Include every necessary action that cannot be safely completed through repository changes alone, including actions in ALL-INKL KAS, DNS delegation, credential setup, state import or backup where applicable, propagation checks, and final service verification.

For each manual task, explain:

- Why it is needed.
- Where it must be performed.
- The exact action to take, to the extent supported by the available information.
- How to verify that it succeeded.
- Whether it must happen before, during, or after the automated implementation.
- Any potential downtime or rollback implications.

Do not mark manual tasks as completed.

## 10. Final response

After creating the story, summarize:

- The story's repository path.
- The proposed DNS architecture.
- The principal implementation tasks.
- The manual actions that will remain my responsibility.
- Any unresolved questions or prerequisites that prevent a fully specified implementation.

Do not implement the story, modify production DNS, change nameservers, apply OpenTofu, or delete existing DNS records as part of this task.
```
