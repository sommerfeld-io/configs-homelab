---
title: 'Grafana Cloud Synthetic Monitoring checks in OpenTofu'
type: 'refactor'
created: '2026-10-16'
status: 'done'
route: 'one-shot'
review_loop_iteration: 0
context:
    - '{project-root}/_bmad-output/implementation-artifacts/spec-2-1-devcontainer-tools-and-digitalocean-token-delivery.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-2-4-opentofu-droplet-ssh-keys-tag-and-project.md'
    - '{project-root}/_bmad-output/planning-artifacts/epics-fantasy-hockey-digitalocean.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The two Grafana Cloud Synthetic Monitoring HTTP checks for `www.fb-brunnenbau.de` (check `78145`) and `www.minifigs.de` (check `78146`) and their alert rules were created by hand in the Grafana Cloud UI. Nobody reviews changes to them, and nothing in the repo describes them. The Terraform export of the UI inlines the Grafana service account token and the SM access token, repeats the minifigs check and its alerts twice with slightly different attributes, and names resources after mangled URLs.

**Approach:** A new OpenTofu root `grafana-cloud/opentofu` declares the checks and their alerts, following the blueprint `configs-cloud/digital-ocean/opentofu`: one root module, configuration in `locals`, `this`-style `for_each` resources, exact version pins, local state and a taskfile. The provider reads its only secret, a Synthetic Monitoring access token, from the environment variable `GRAFANA_SM_ACCESS_TOKEN`. The token reaches the shell through the Ansible vault, `bash-secrets.yml` and the devcontainer `containerEnv`, the same path as `DIGITALOCEAN_ACCESS_TOKEN`. OpenTofu fully owns the checks: the operator deletes the two UI-created checks in Grafana Cloud, and the first apply creates them again from `checks.tf`. Nothing is imported.

**Decisions (2026-10-16):**

- **Dedicated SM access token, not the Alloy key:** `grafana_cloud_api_key` (`GCLOUD_RW_API_KEY` for Alloy) is an access policy token for writing metrics, logs and traces. The Synthetic Monitoring API does not accept it. The operator created a Synthetic Monitoring access token and stored it as `GRAFANA_SM_ACCESS_TOKEN` in `configs-homelab/ansible/vars/grafana-vault.yml`.
- **No Grafana instance URL or service account token:** only `grafana_synthetic_monitoring_*` resources are managed. They need `sm_url` and `sm_access_token` only, so `url` and `auth` are left out of the provider block.
- **No folders (operator, 2026-10-16):** sorting the checks into Grafana folders (`folder_uid`) was built and dropped again. The folders would be `grafana_folder` resources in the Grafana instance API, which needs a second secret (a service account token in `GRAFANA_AUTH`). The operator chose to keep a single token.
- **The variable name is the provider's own:** `GRAFANA_SM_ACCESS_TOKEN` is the environment variable the `grafana/grafana` provider reads for `sm_access_token`. The same name is used in the vault, `.bashrc` and the devcontainer, so no `TF_VAR_` mapping and no `variable` block are needed.
- **`sm_url` stays inline:** `https://synthetic-monitoring-api-eu-west-2.grafana.net` is not secret and changes only when the stack moves region.
- **Root taskfile prefix `grafana-cloud`:** the operator asked for this prefix, so tasks are called as `task grafana-cloud:<name>`.
- **Clean slate instead of import (operator, 2026-10-16):** the checks are deleted in the UI and recreated by OpenTofu, so the state never holds anything that was not created from this configuration. The cost: new check IDs, and the checks are briefly absent between the delete and the apply. Earlier results stay in Grafana Cloud's metrics. Anything outside this configuration that points at the old check IDs `78145` and `78146` breaks.
- **No GitHub Actions workflow yet:** the configuration is applied locally only. CI and remote state can follow the plan for Epic 6.

## Boundaries & Constraints

**Always:**

- One entry per website in `local.checks` in `checks.tf`, with its own `job` and `probes`. The other settings (frequency, timeout, HTTP settings, alert names and periods) live once in `locals` or in the resource body, never per entry.
- No probe IDs in the configuration: probe locations are looked up by name (`probes.tf`) and referenced as `local.probe_location_<name>`.
- Key `for_each` by site name. The key also becomes the `site` label, so the label never diverges from the key.
- Pin OpenTofu (`1.12.7`, same as the devcontainer and `lint-opentofu`) and `grafana/grafana` exactly. Commit `.terraform.lock.hcl`.
- `plan`, `apply` and `apply:yes` fail early with a hint to the docs when `GRAFANA_SM_ACCESS_TOKEN` is empty.
- After the first apply, a second `tofu plan -detailed-exitcode` exits `0`.
- Update the docs and the `mkdocs.yml` nav in the same change. `task lint` passes.

**Never:**

- No token, password or key in any committed file. The UI export is not committed.
- The agent never runs `tofu apply` or `apply:yes`, and never deletes checks in Grafana Cloud. The operator does both (Manual Tasks).
- No `import` blocks and no `tofu import` in the normal workflow. Import is only the recovery path for a lost state (docs, §State).
- No GitHub Actions workflow, remote backend, module or workspace.
- No change to the Alloy key, the Alloy config or the homelab Grafana manifests (`grafana-cloud/manifests`).

## I/O & Edge-Case Matrix

| Scenario                   | Input / State                                       | Expected                                                          | Error Handling                                                                                                      |
|----------------------------|-----------------------------------------------------|-------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| First apply                | empty state, UI-created checks deleted              | plan `4 to add`; apply creates both checks and their alerts       | a UI check for the same target and job still exists → `409 Conflict`, nothing is created: delete it and apply again |
| Plan after apply           | state from the first apply, unchanged configuration | `No changes.`, exit code `0`                                      | a perpetual diff is a defect: spell out the value the API returns                                                   |
| Token missing              | `GRAFANA_SM_ACCESS_TOKEN` empty                     | `task grafana-cloud:plan` stops with a hint to the docs           | rebuild the devcontainer from a shell where the variable is set                                                     |
| New website                | new entry in `local.checks`                         | plan creates one check and one alerts resource                    | N/A                                                                                                                 |
| Duration threshold changed | `http_duration_threshold_ms` changed                | alerts resource updated in place                                  | N/A                                                                                                                 |
| Website removed            | entry removed from `local.checks`                   | plan destroys the check and its alerts                            | review the plan: the check's history stays in Grafana Cloud metrics                                                 |
| Local state lost           | no `terraform.tfstate`                              | plan `4 to add`; apply fails with `409 Conflict`, nothing changes | delete the checks in the UI and apply, or `tofu import` them by check ID (docs §State)                              |

</frozen-after-approval>

## Code Map

- `grafana-cloud/opentofu/versions.tf`: OpenTofu `1.12.7`, `grafana/grafana` `4.47.0` (newest release at least two weeks old on 2026-10-16), provider with `sm_url` only.
- `grafana-cloud/opentofu/probes.tf`: `data.grafana_synthetic_monitoring_probes.this` and `local.probe_location_frankfurt` / `local.probe_location_paris`.
- `grafana-cloud/opentofu/checks.tf`: `local.checks` (options header like `droplets.tf`, `job` and `probes` per check), shared settings, `grafana_synthetic_monitoring_check.this`, `grafana_synthetic_monitoring_check_alerts.this` (`check_id` references the check, not a copied ID).
- `grafana-cloud/opentofu/outputs.tf`: `check_ids` keyed by site.
- `grafana-cloud/opentofu/taskfile.yml`: `init`, `fmt`, `validate`, `plan`, `apply`, `apply:yes` with the `GRAFANA_SM_ACCESS_TOKEN` precondition anchor.
- `taskfile.yml` (root): include `grafana-cloud` with `dir: grafana-cloud/opentofu`. `lint` runs `grafana-cloud:fmt`.
- `docker-compose.yml`: `lint-opentofu` checks `configs-cloud` and `grafana-cloud`.
- `.folderslintrc`: allow `grafana-cloud/opentofu`.
- `.devcontainer/devcontainer.json`: `containerEnv` `GRAFANA_SM_ACCESS_TOKEN` from `${localEnv:GRAFANA_SM_ACCESS_TOKEN}`.
- `configs-homelab/ansible/playbooks/desktop.yml`: loads `grafana-vault.yml` and exports `GRAFANA_SM_ACCESS_TOKEN` through `bash-secrets.yml` (done by the operator).
- `docs/grafana-cloud/synthetic-monitoring.md` and the top-level `mkdocs.yml` nav section `Grafana Cloud`.

## Tasks & Acceptance

**Execution:**

- [x] Create the OpenTofu root, `tofu init`, `tofu fmt`, `tofu validate`.
- [x] Wire the taskfile, linters, folderslint and the devcontainer.
- [x] Write the docs page and the nav entry.
- [x] `task lint` passes.
- [x] Operator deletes the UI checks (M4), then runs `task grafana-cloud:plan` (expect `4 to add, 0 to change, 0 to destroy`) and `task grafana-cloud:apply` (M5).
- [x] A second `tofu plan -detailed-exitcode` exits `0`. Fix the config for any perpetual diff.

**Acceptance Criteria:**

- Given the state of the first apply, when `task grafana-cloud:plan` runs, then it reports `No changes.`
- Given the Grafana Cloud UI, when the checks are listed, then exactly one check per entry in `local.checks` exists, with the `site` label and the three alerts.
- Given `git grep` over the repo, when searching for the token values, then nothing is found, and `terraform.tfstate` is untracked.
- Given an empty `GRAFANA_SM_ACCESS_TOKEN`, when `task grafana-cloud:plan` runs, then it stops with the hint to the docs.

## Manual Tasks (Operator)

| #  | When         | Where                                   | Action                                                                                | Verify                                           |
|----|--------------|-----------------------------------------|---------------------------------------------------------------------------------------|--------------------------------------------------|
| M1 | before apply | Grafana Cloud → Synthetics → Config     | Create a Synthetic Monitoring access token                                            | token shown once                                 |
| M2 | before apply | `grafana-vault.yml`, `desktop` playbook | Store it as `GRAFANA_SM_ACCESS_TOKEN`, run the `desktop` playbook                     | `echo "${GRAFANA_SM_ACCESS_TOKEN:+set}"` on host |
| M3 | before apply | VS Code                                 | Start VS Code from a shell with the variable set, rebuild the devcontainer            | same check inside the devcontainer               |
| M4 | before apply | Grafana Cloud → Synthetics → Checks     | Delete the checks for `www.fb-brunnenbau.de` (78145) and `www.minifigs.de` (78146)    | both gone from the list                          |
| M5 | after M4     | host or devcontainer                    | `task grafana-cloud:plan`, read it, then `task grafana-cloud:apply` (not `apply:yes`) | second plan says `No changes.`                   |

## Implementation Notes

**2026-10-16, first apply (clean slate):** the operator deleted the UI checks 78145 and 78146. `task grafana-cloud:plan` showed `4 to add, 0 to change, 0 to destroy`, and the apply created `www.fb-brunnenbau.de` as check `94170` and `www.minifigs.de` as check `94171`, each with its three alerts. The second `task grafana-cloud:plan` reported `No changes.` No provider default had to be spelled out.

**2026-10-16, apply before import:** the operator ran `task grafana-cloud:apply:yes` on the host with an empty state. The plan said `4 to add`. Grafana Cloud refused both check creates with `409 Conflict: target/job combination already exists`. The alerts depend on the checks and were not attempted, and the state stayed empty, so nothing in Grafana Cloud changed. An `imports.tf` with `import` blocks was drafted to adopt the checks, then dropped: the operator chose a clean slate instead, so OpenTofu creates every check itself (Decisions).

## Design Notes

**Recovery import IDs:** only needed when the state is lost. `grafana_synthetic_monitoring_check` imports by the check ID, `grafana_synthetic_monitoring_check_alerts` by the `check_id` of its check (provider docs `v4.47.0`).

**The duplicated export:** the UI export lists the minifigs check and its alerts twice. The second copy spells out the provider defaults (`compression = "none"`, empty `headers`, `valid_status_codes` and other lists). The configuration uses the short form and lets the provider defaults apply. The second plan after the first apply shows whether a default must be spelled out.

**Jobs and probes per check (operator, 2026-10-16):** `job` and `probes` moved into each entry of `local.checks`. The website checks use the job `up-and-running___websites`, the fantasy hockey check `up-and-running___digital-ocean`. The probe IDs `14` and `19` from the UI export were magic numbers, and which one is Frankfurt was not recorded anywhere, so `probes.tf` resolves them by name. Locals are lowercase snake_case (`probe_location_paris`), the HCL naming convention; upper case is left to environment variables. They are `locals`, not `variable` blocks, because nobody passes them in from outside: the blueprint keeps configuration in `locals`. Both `job` and `probes` update in place (no `ForceNew`, `probes` is a set), so the existing checks keep their IDs.

**Story 5.2 (2026-10-16):** the check for `https://fantasy-hockey.prod.do.sommerfeld.app` is one more entry in `local.checks`. Its acceptance criterion "fails when the certificate expires within 14 days" added the optional per-check option `tls_expiry_threshold_days` (default 5, so the website checks are unchanged).

## Verification

```bash
cd grafana-cloud/opentofu
tofu validate
tofu plan -detailed-exitcode   # 0 = no changes
cd ../.. && task lint
```
