# Research: OpenTofu State on DigitalOcean Spaces

- **Date:** 2026-10-29
- **Source:** an answer from Gemini, pasted by the user into the Story 6.2 planning conversation
- **Used by:** Story 6.2 "Remote state with locking" in `epics-fantasy-hockey-digitalocean.md`

## Corrections for this Repo

The guide below is kept as received. It is generic and does not match this repo in these points; Story 6.2 follows the corrections, not the guide:

- **Version:** `use_lockfile` needs OpenTofu 1.10 or later. The guide's `required_version = ">= 1.6.3"` and `tofu_version: "1.8.x"` would not support it. This repo pins OpenTofu `1.12.8` exactly.
- **Provider:** the repo pins `digitalocean/digitalocean` `2.106.0` with a lock file, not `opentofu/digitalocean ~> 2.0`.
- **Endpoint:** current OpenTofu versions deprecate the S3 backend's `endpoint` argument in favour of `endpoints = { s3 = "https://<region>.digitaloceanspaces.com" }`.
- **Locking on Spaces:** `use_lockfile` relies on conditional writes. The guide states that it works on Spaces without proof; Story 6.2 keeps the two-runs-at-once test as the proof.
- **`encrypt = true`:** this requests AWS server-side encryption; whether Spaces honours or rejects it is unverified. It is not client-side encryption; OpenTofu's own state encryption is a separate option.
- **Token variable:** the provider here reads `DIGITALOCEAN_ACCESS_TOKEN`, exported from the vault by `bash-secrets.yml`, not `DIGITALOCEAN_TOKEN` from `.bashrc`.
- **Secrets:** AD-6 puts CI secrets at the organization level, not the repository level.
- **Workflow:** the workflow belongs to Story 6.3, and AD-1 says `cloud-deployment.yml` runs only on `main`, not on pull requests. The workflow's `run` script is also incomplete: the `if` has no `fi`, and `-lock-timeout=60s` stands alone on its own line.
- **Bucket layout:** the user decided on one bucket with one key per root (`opentofu/state/digital-ocean`, `opentofu/state/grafana-cloud`), not `prod/terraform.tfstate`.

## Guide as Received

To manage your OpenTofu state securely, centrally, and safely across both your local machine and GitHub Actions, the industry standard is to store it in **DigitalOcean Spaces** (which is S3-compatible object storage) and use OpenTofu's native S3 state locking (`use_lockfile = true`). This eliminates the need for extra services like DynamoDB (which DigitalOcean doesn't have) and ensures that parallel write operations are safely blocked.

Here is a complete, step-by-step guide to setting this up.

### Step 1: Create a DigitalOcean Space for State

Create a private Spaces bucket (e.g., `my-tofu-state`) in a region of your choice (e.g., `nyc3` or `fra1`).

1. Go to your DigitalOcean Dashboard -> **Spaces** -> **Create Spaces Bucket**.
2. Name it, choose a datacenter region, and make sure **Restricted File Listing** (private) is selected.
3. Generate a set of **Spaces Access Keys** (API Token) with Read/Write permissions and save the `Access Key ID` and `Secret Access Key`.

### Step 2: Configure the OpenTofu Backend

In your OpenTofu configuration (e.g., `versions.tf` or `main.tf`), configure the `s3` backend. Because DigitalOcean Spaces uses an S3-compatible API, you point the S3 backend to DigitalOcean's endpoint using `endpoint` and bypass AWS-specific checks via the `skip_*` flags.

```hcl
terraform {
  required_version = ">= 1.6.3"

  required_providers {
    digitalocean = {
      source  = "opentofu/digitalocean"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket                      = "my-tofu-state"          # Your Spaces bucket name
    key                         = "prod/terraform.tfstate" # Path/name inside the bucket
    region                      = "us-east-1"              # OpenTofu requires a region value; DO Spaces ignores it, use a dummy value like "us-east-1"
    endpoint                    = "nyc3.digitaloceanspaces.com" # Your DO Space endpoint region URL (without https://)
    encrypt                     = true
    use_lockfile                = true                     # Native S3 state locking (prevents race conditions/corruption)
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
```

### Step 3: Set Up Local Environment Secrets

Never hardcode your Spaces keys in your code, as backend blocks don't support variables. Instead, export them locally as environment variables.

Add these to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export AWS_ACCESS_KEY_ID="your_spaces_access_key_id"
export AWS_SECRET_ACCESS_KEY="your_spaces_secret_access_key"
```

*(OpenTofu's S3 backend reads `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to authenticate against S3-compatible endpoints like Spaces).*

Once set, run:

```bash
tofu init
```

If you already have a local state, OpenTofu will ask if you want to migrate it to the remote Spaces backend. Type `yes`.

### Step 4: Configure GitHub Actions for CI/CD

To allow GitHub Actions to run OpenTofu against the same state safely, use GitHub Secrets and a workflow file.

#### 1. Add GitHub Repository Secrets

Go to your GitHub repository -> **Settings** -> **Secrets and variables** -> **Actions** and add:

- `SPACES_ACCESS_KEY_ID`: Your Spaces access key.
- `SPACES_SECRET_ACCESS_KEY`: Your Spaces secret key.
- `DIGITALOCEAN_TOKEN`: Your regular DigitalOcean API token (needed for the DigitalOcean provider to provision resources).

#### 2. Create the GitHub Actions Workflow (`.github/workflows/tofu.yml`)

This workflow runs a `plan` on Pull Requests and an `apply` when merged to `main`. It includes concurrency settings to prevent simultaneous pipeline runs from stepping on each other.

```yaml
name: OpenTofu Deploy

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

# Prevent concurrent runs on the same branch/environment from overlapping
concurrency:
  group: tofu-deployment
  cancel-in-progress: false

jobs:
  tofu:
    name: "OpenTofu Validate & Apply"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: "1.8.x" # Or your preferred version supporting use_lockfile

      - name: Run Tofu Init & Plan / Apply
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.SPACES_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.SPACES_SECRET_ACCESS_KEY }}
          DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}
        run: |
          tofu init -input=false
          tofu validate

          if [ "${{ github.event_name }}" == "push" ] && [ "${{ github.ref }}" == "refs/heads/main" ]; then
            tofu apply -auto-approve
          else
            tofu plan
          -lock-timeout=60s
```

### How This Solves the Requirements

1. **Centralized & Secure:** The state file lives securely inside your private DigitalOcean Spaces bucket, encrypted at rest. Secrets are kept out of git tracking (`.tfstate` is ignored).
2. **No Corruption / Parallel Safety (`use_lockfile = true`):** When either you run `tofu apply` locally or GitHub Actions runs it in the cloud, OpenTofu automatically creates a `.tflock` object in the bucket. If another process tries to write to the state at the same time, it will fail gracefully or wait (`-lock-timeout=60s`), preventing state corruption.
3. **Seamless Local/CI Sync:** Because both environments point to the exact same bucket, key, and endpoint, running `tofu plan` locally will pull the exact same source of truth that GitHub Actions uses.
