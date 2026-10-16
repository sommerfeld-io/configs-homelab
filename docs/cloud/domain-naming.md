# Domain Naming

Every app deployment in the cloud gets a hostname that says which app it is, which stage it runs in and which cloud provider hosts it.

## Pattern

```text
<app>.<stage>.<cloud-provider>.sommerfeld.app
```

Example: `fantasy-hockey.prod.do.sommerfeld.app` is the fantasy hockey app in `prod` on DigitalOcean.

## Stages

- `dev` → Development deployments
- `test` → Test deployments before a release
- `prod` → Production deployments used for real

No other stages are allowed. For DigitalOcean, OpenTofu enforces the list: `tofu plan` fails for a droplet with any other `stage` (`local.stages` in `configs-cloud/digital-ocean/opentofu/droplets.tf`).

## Cloud Providers

- `do` → DigitalOcean
- `linode` → Linode
- `aws` → AWS
- `gcp` → Google Cloud

No other provider names are allowed. A new provider gets a short name in this list before its first deployment.

## Domains

- `sommerfeld.app` → Actual app deployments, always under a name that follows the pattern above
- `sommerfeld.io` → The organization's website, which at the moment redirects to GitHub. No app deployments here.

How the DNS record for a DigitalOcean deployment is created and checked is described in [Domain](digital-ocean/domain.md).
