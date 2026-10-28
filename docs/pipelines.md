# CI/CD Pipeline

## Overview

All automation runs as GitHub Actions workflows in `.github/workflows/`. Several workflows delegate their jobs to reusable workflows in the organization repository [sommerfeld-io/.github](https://github.com/sommerfeld-io/.github) (referenced as `sommerfeld-io/.github/.github/workflows/<name>.yml@main`).

The two workflows that matter for changes in this repository are:

- **`pipeline.yml` ("Pipeline: Commit + Test")** checks every push, generates docs and, on `main`, runs Semantic Release.
- **`release.yml` ("Pipeline: Release")** runs when Semantic Release creates a GitHub release. It completes the release notes and publishes the documentation site to GitHub Pages.

There is **no `cloud-deployment.yml` yet**. Nothing in CI applies OpenTofu or deploys to DigitalOcean today; changes under `configs-cloud/` are applied by an operator from a workstation (see [Cloud Deployment Pipeline](#cloud-deployment-pipeline)).

A **trigger** (`on:`) decides whether GitHub starts a workflow run at all. A **job or step condition** (`if:`) is evaluated inside a run that has already started and decides whether that job or step executes or is skipped. Both appear below.

Every workflow run is independent. A run never "continues" in another workflow; one workflow only causes another by producing a GitHub event (for example a release) that the other workflow listens to.

## Workflow Inventory and Triggers

| Workflow                                                                     | Trigger                                                                                    | Conditions                                                                                                                                                                                                                                                                                                     | Purpose                                                                              | Result                                                                                                                         |
|------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| `pipeline.yml` (Pipeline: Commit + Test)                                     | `push`; `schedule` `0 1 * * 2` (Tuesday 01:00 UTC)                                         | Push: all branches except `dependabot/**`, and not when every changed file matches `paths-ignore` (`**.adoc`, `**.md`, `docs/**`, `.devcontainer/**`, `.github/workflows/dev-environment.yml`, `.vscode/**`, `.gitkeep`). Tag pushes never start it. Job conditions: see [Release Pipeline](#release-pipeline) | Lint, ShellCheck, InSpec profile checks, Molecule, docs generation, Semantic Release | Possible commit `docs: [Actions Bot] generate docs` on the pushed branch; on `main` possibly a version, tag and GitHub release |
| `release.yml` (Pipeline: Release)                                            | `release` with type `created`                                                              | None                                                                                                                                                                                                                                                                                                           | Complete the release notes, build and publish the docs site                          | Edited GitHub release notes; deployment to the `github-pages` environment                                                      |
| `codeql.yml` (CodeQL Advanced)                                               | `push` to `main`; `pull_request` against `main`; `schedule` `0 5 * * 0` (Sunday 05:00 UTC) | Push: `paths-ignore` like `pipeline.yml` but without `docs/**`                                                                                                                                                                                                                                                 | Code scanning of the GitHub Actions workflows (language `actions`)                   | Code scanning results                                                                                                          |
| `dev-environment.yml` (Development Environment)                              | `push`; `schedule` `0 1 * * 2`; `workflow_dispatch`                                        | Push: all branches except `dependabot/**`, only for changes in `.devcontainer/**` or `.github/workflows/dev-environment.yml`                                                                                                                                                                                   | Lint (hadolint) and build the devcontainer image without pushing it                  | Build result only                                                                                                              |
| `housekeeping-issues.yml` (Housekeeping: Issues + PRs)                       | `issues` `opened`; `pull_request` `opened`, `assigned`                                     | Labeling job only for issues without the `story` label                                                                                                                                                                                                                                                         | Add issues and PRs to the organization project, set default labels                   | Project items and labels                                                                                                       |
| `housekeeping-project.yml` (Housekeeping: Issues in Project)                 | `issues` `labeled`, `unlabeled`; `schedule` `0 6 * * *`                                    | Move-to-backlog job only when the label `review-me` is added                                                                                                                                                                                                                                                   | Keep the organization project board in sync                                          | Project item status                                                                                                            |
| `housekeeping-labels.yml` (Housekeeping: Labels)                             | `schedule` `0 1 * * *`; `push` to `main`                                                   | Push: only for changes in `.github/workflows/housekeeping-labels.yml`                                                                                                                                                                                                                                          | Reset the repository labels to the organization standard                             | Labels                                                                                                                         |
| `housekeeping-issues-ai-refinement.yml` (Housekeeping: Issues AI Refinement) | `schedule` `30 5 * * *`                                                                    | Triage step only when open issues carry `needs-triage`                                                                                                                                                                                                                                                         | AI triage of new issues with the GitHub Copilot CLI                                  | Triaged issues                                                                                                                 |

Dependabot is configured in `.github/dependabot.yml` (see [Dependabot Integration](#dependabot-integration)). Its update jobs run on GitHub's side as "dynamic" workflow runs and are not files in this repository.

## Release Pipeline

### Inside One `pipeline.yml` Run

`pipeline.yml` runs these jobs in a single workflow run:

1. **`shellcheck`** and **`lint`** (matrix of the `docker-compose.yml` linters `yaml`, `workflows`, `filenames`, `folders`, `markdown-links`, `ansible`, `opentofu`, `alloy-config`) start in parallel.
2. When both succeed, four find jobs list what the next jobs run, each with a script in `.github/workflows/assets/`: **`find-opentofu-roots`** (`find-opentofu-roots.sh`, every folder with a tracked `versions.tf`), **`find-inspec-profiles`** (`find-inspec-profiles.sh`, every folder with a tracked `inspec.yml`), **`find-molecule`** (`find-molecule.sh`, every folder below `configs-homelab/` with a tracked `molecule/default/molecule.yml`) and **`find-molecule-cloud`** (`find-molecule-cloud.sh`, the same below `configs-cloud/`). The matching tasks (`task opentofu:validate`, `task homelab:inspec:check`, `task homelab:molecule:test`, `task cloud:molecule:test`) read the same lists, so a new root, profile or scenario needs no edit to a task or the pipeline.
3. Each find job starts its own matrix job, one entry per path, as soon as it succeeds: **`validate-opentofu`** runs `tofu validate` per root, **`check-inspec-profile`** runs `task homelab:inspec:check:<path>` (vendor and `inspec check`) per profile, **`molecule`** runs `task homelab:molecule:test:<path>` for the homelab roles and **`molecule-cloud`** runs `task cloud:molecule:test:<path>` for the roles the DigitalOcean droplet runs (see [Tests](cloud/digital-ocean/tests.md)). Every Molecule scenario runs to the end (`fail-fast: false`). Both Molecule jobs and `generate-docs` have `if: github.actor != 'dependabot[bot]'`.
4. When all four matrix jobs succeed, **`generate-docs`** starts.
    - `generate-docs` runs `task docs:generate`, builds the `docs-build` image and commits changed files as `docs: [Actions Bot] generate docs` to the pushed branch. This happens on every branch, not only on `main`. The docs site itself is not built or published here.
5. When `generate-docs` succeeds, **`release-code`** calls the reusable workflow `lib-release-code.yml`. It has `if: github.actor != 'dependabot[bot]' && github.ref == 'refs/heads/main'`, so on any other branch it is skipped and the run ends here.

### Semantic Release

`release-code` installs Semantic Release and runs `npx semantic-release` with the organization secret `GH_TOKEN_REPO_AND_PROJECT` (a personal access token) as `GITHUB_TOKEN`. The configuration is `.releaserc.js`:

- **`@semantic-release/commit-analyzer`** reads the Conventional Commits since the last release tag. With the default rules, `fix` and `perf` give a patch release, `feat` a minor release and a `BREAKING CHANGE:` footer a major release. `refactor`, `docs`, `chore` and the other types give no release.
- **No release needed:** Semantic Release stops without a tag or release. The remaining steps of the job still run: they read the latest existing tag and the commit step finds nothing to commit. Nothing else is triggered.
- **Release needed:**
    1. `@semantic-release/npm` sets the version in `package.json` (`npmPublish: false`).
    2. `@semantic-release/exec` runs `.github/workflows/assets/release.sh <version>`, which writes the version into `configs-homelab/tests/inspec/*/inspec.yml`.
    3. `@semantic-release/git` commits `package.json` and `package-lock.json` as `refactor(release): bump version to <version> [Actions Bot]` (author `semantic-release-bot`) and pushes it to `main`, together with the tag `v<version>`.
    4. `@semantic-release/github` creates the GitHub release for the tag, with notes from `@semantic-release/release-notes-generator` and the header `.github/workflows/assets/release-notes-header.hbs`.
    5. After Semantic Release, the job commits the remaining changes (the `inspec.yml` versions) with the same message and pushes them to `main`.

### How `release.yml` Is Triggered

`release.yml` listens to `release: types: [created]`, not to tag pushes. The trigger is the GitHub release that `@semantic-release/github` creates. Because that release is created with the personal access token, GitHub emits the `release` event and starts a separate `release.yml` run. Events caused by the built-in `GITHUB_TOKEN` do not start workflows, so the PAT is what makes this hand-over work.

The tag push itself starts nothing: `pipeline.yml`, `codeql.yml` and `dev-environment.yml` only define branch filters, and a workflow with only branch filters does not run for tag pushes.

The two version-bump commits and the `generate-docs` commit do not start a new `pipeline.yml` run either. The run history confirms this: for release `v0.108.0`, the commits from `semantic-release-bot` and from the release job left no further push run on `main`.

### Inside One `release.yml` Run

1. **`update-release-notes`** calls the reusable workflow `release.yml` from `sommerfeld-io/.github`:
    - `update-release-notes` appends a section "Closed Issues and Pull Requests" (everything closed since the previous release) to the release notes.
    - `generate-release-intro` asks the GitHub Copilot CLI (secret `COPILOT_CLI_TOKEN`) for a short description of the release and prepends it. If Copilot produces nothing, this step is skipped and the release stays without intro.
2. **`docs-build`** checks out the release tag (`github.ref`), runs `docker compose up docs-build` (MkDocs) and uploads `target/docs/site` as the pages artifact `docs-page`.
3. **`docs-deploy`** (after `docs-build`) deploys the artifact to GitHub Pages in the environment `github-pages`.

`update-release-notes` and `docs-build` run in parallel; publishing the docs does not wait for the release notes.

## Cloud Deployment Pipeline

**There is no `cloud-deployment.yml` in this repository yet.** No workflow watches `configs-cloud/`, and nothing in CI runs OpenTofu or deploys to the DigitalOcean droplet.

What exists today:

- **Local apply:** OpenTofu runs from the operator's devcontainer through `task cloud:digital-ocean:{init,fmt,plan,apply}` with a local state file. See [Tasks and Linters](cloud/digital-ocean/tasks-and-linters.md) and [Droplet](cloud/digital-ocean/droplet.md).
- **CI checks:** a push that changes `configs-cloud/` runs `pipeline.yml`. It covers that folder with `lint-opentofu` (`tofu fmt -check`), the `validate-opentofu` job (`tofu validate` for each OpenTofu root module), ansible-lint, folderslint, ls-lint and yamllint, but it runs no plan and no apply.

What is planned (backlog stories in `_bmad-output/implementation-artifacts/sprint-status.yaml`, decided in architecture decision AD-10):

- **Story 6.1:** OpenTofu and Ansible static checks in CI.
- **Story 6.2:** remote OpenTofu state with locking, so CI and localhost can share the state.
- **Story 6.3:** `cloud-deployment.yml`, the single CI apply path. It runs only on `main`, is serialized by a concurrency group, applies changes under `configs-cloud/digital-ocean` (static checks, OpenTofu, provisioning and app deployment) with organization secrets (DigitalOcean token, vault password, CI SSH key).

Until Story 6.3 is done, a merged change under `configs-cloud/` reaches DigitalOcean only when an operator runs the apply task.

## Dependabot Integration

### What Dependabot Watches

`.github/dependabot.yml` defines weekly updates for:

| Ecosystem        | Directory                                                                                                          |
|------------------|--------------------------------------------------------------------------------------------------------------------|
| `github-actions` | `/`                                                                                                                |
| `docker`         | `.devcontainer`                                                                                                    |
| `docker-compose` | `/` (the linters in `docker-compose.yml`)                                                                          |
| `docker-compose` | `configs-homelab/ansible/roles/common/taskfile-dev/files/docker-stacks/portainer`                                  |
| `docker-compose` | `configs-homelab/ansible/roles/grafana-cloud/exporters/files` (cAdvisor on the homelab nodes and on the droplet)   |
| `docker-compose` | `configs-homelab/ansible/roles/media/jellyfin/files`                                                               |
| `docker-compose` | `configs-homelab/ansible/roles/raspi/fritz-box-exporter/files`                                                     |
| `docker-compose` | `configs-homelab/ansible/roles/raspi/pihole/files`                                                                 |
| `docker-compose` | `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/files` (the fantasy hockey app and Caddy on the droplet) |
| `opentofu`       | `/configs-cloud/digital-ocean/opentofu` (the `digitalocean` provider)                                              |
| `opentofu`       | `/grafana-cloud/opentofu` (the `grafana` provider)                                                                 |

The fantasy-hockey compose file moved from the RasPi role to `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey`, and its Dependabot entry moved with it, so a compose bump is a change under `configs-cloud/digital-ocean`. Nothing redeploys the droplet after a merged bump yet: run `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` by hand (see [Deployment](cloud/digital-ocean/deployment.md)).

An `opentofu` bump only changes the provider pin in `versions.tf` and `.terraform.lock.hcl`. Nothing applies it: after the merge, run `tofu init` (installs the new provider from the lock file) and the `plan` task of that config (`task cloud:digital-ocean:opentofu:plan` or `task grafana-cloud:plan`), and expect `No changes.` A provider upgrade that suddenly shows changes needs a look before any apply.

The droplet also runs fleet roles from `configs-homelab/`: `grafana-cloud/exporters` (cAdvisor) and `grafana-cloud/alloy`. A Dependabot cAdvisor bump in `configs-homelab/ansible/roles/grafana-cloud/exporters/files`, or an edit to either role, is a change under `configs-homelab/`, not under `configs-cloud/`, and reaches the droplet only when an operator runs `task cloud:digital-ocean:ansible:provision` (see [Provisioning](cloud/digital-ocean/provisioning.md)). Dependabot has no Alloy entry: Alloy itself comes from the Grafana APT repo on the next provision run.

### From Dependabot Pull Request to `main`

1. **Dependabot opens a pull request** from a branch `dependabot/<ecosystem>/...`.
2. **Checks on the pull request:** only workflows with a `pull_request` trigger run:
    - `codeql.yml` (`pull_request` against `main`)
    - `housekeeping-issues.yml` (`pull_request` `opened`, `assigned`), which adds the PR to the project
3. **`pipeline.yml` does not run for Dependabot pull requests.** It has no `pull_request` trigger, and its `push` trigger ignores `dependabot/**` branches. Lint, InSpec checks and Molecule run only after the merge.
4. **No merge restrictions:** `main` has no branch protection and no rulesets (verified through the GitHub API), so no status check is required and Dependabot PRs are merged manually. Auto-merge is not configured.
5. **The merge creates a push to `main`** by the person who merged. This push starts `pipeline.yml` and `codeql.yml` like any other push. `github.actor` is that person, not `dependabot[bot]`, so `molecule`, `molecule-cloud`, `generate-docs` and `release-code` run as well.
6. **Release:** Dependabot commits use the `chore(deps)` / `chore(deps-dev)` prefixes, which give no release on their own. They are released together with the next `feat` or `fix`.
7. **No deployment:** nothing deploys the updated version. For fleet roles, the change reaches a node with the next playbook run, and the droplet (a cAdvisor bump in `grafana-cloud/exporters`) with the next `task cloud:digital-ocean:ansible:provision`; for `configs-cloud/`, an operator applies it (see [Cloud Deployment Pipeline](#cloud-deployment-pipeline)).

The `github.actor != 'dependabot[bot]'` conditions in `pipeline.yml` are a safeguard. With the current triggers, Dependabot is never the actor of a `pipeline.yml` run.

## Sequence Diagrams

### Release and Documentation Publication

```kroki-plantuml
@startuml
autonumber
actor Developer
participant "GitHub" as GH
box "pipeline.yml run" #F2F7FC
  participant "checks\nshellcheck, lint,\nfind jobs, then\nvalidate-opentofu,\ncheck-inspec-profile" as Checks
  participant "molecule, molecule-cloud\nthen generate-docs" as Build
  participant "release-code\n(lib-release-code.yml)" as Rel
end box
box "release.yml run" #F4FBF2
  participant "update-release-notes" as Notes
  participant "docs-build +\ndocs-deploy" as Docs
end box
participant "GitHub Pages" as Pages

Developer -> GH : git push (branch)
GH -> Checks ++ : push event\n(branch filter and paths-ignore match)
Checks --> Build -- : all checks succeeded
activate Build
Build -> GH : commit "docs: [Actions Bot] generate docs"\n(if docs changed, GITHUB_TOKEN, no new run)
Build --> Rel -- : molecule, molecule-cloud and generate-docs succeeded
activate Rel
alt github.ref != refs/heads/main
  Rel -> Rel : job skipped, run ends
else github.ref == refs/heads/main
  Rel -> Rel : npx semantic-release (PAT)
  alt no feat, fix, perf or BREAKING CHANGE since last tag
    Rel -> Rel : no release, run ends
  else release warranted
    Rel -> GH : push version commit + tag v<version>\n(tag push starts no workflow)
    Rel -> GH : create GitHub release (PAT)
    Rel -> GH : commit inspec.yml versions
  end
end
deactivate Rel

== separate workflow run ==

GH -> Notes ++ : release created event
GH -> Docs ++ : (same run, parallel job)
Notes -> GH : append closed issues and PRs,\nprepend Copilot intro (if generated)
deactivate Notes
Docs -> Docs : checkout tag, docker compose up docs-build
Docs -> Pages : deploy target/docs/site
deactivate Docs
@enduml
```

### Dependabot Update and Cloud Deployment

```kroki-plantuml
@startuml
autonumber
participant "Dependabot" as Bot
participant "GitHub" as GH
participant "codeql.yml +\nhousekeeping-issues.yml" as PRChecks
actor Maintainer
participant "pipeline.yml" as Pipe
participant "cloud-deployment.yml\n(not implemented, Story 6.3)" as Deploy #EEEEEE
actor Operator
participant "DigitalOcean" as DO

Bot -> GH : open PR from dependabot/<ecosystem>/...
GH -> PRChecks ++ : pull_request event
PRChecks --> GH -- : CodeQL result, PR added to project
note over GH, Pipe : pipeline.yml does not run: no pull_request trigger,\npush trigger ignores dependabot/** branches.\nmain has no required status checks.
Maintainer -> GH : merge PR into main
GH -> Pipe ++ : push event on main (actor = Maintainer)
Pipe -> Pipe : checks, molecule, molecule-cloud, generate-docs, release-code
Pipe --> GH -- : chore(deps) alone gives no release
opt planned with Story 6.3, does not exist today
  GH -> Deploy : push event on main,\nchanges under configs-cloud/digital-ocean
  Deploy -> DO : static checks, OpenTofu apply,\nprovision, deploy
end
Operator -> DO : today: task cloud:digital-ocean:opentofu:apply\nfrom the devcontainer
@enduml
```

### Overall Pipeline Interaction

```kroki-plantuml
@startuml
participant "Developer /\nMaintainer" as Dev
participant "Dependabot" as Bot
participant "GitHub events" as GH
participant "pipeline.yml" as Pipe
participant "codeql.yml" as CodeQL
participant "release.yml" as Rel
participant "dev-environment.yml" as DevEnv
participant "housekeeping-*.yml" as House
participant "GitHub Pages" as Pages

group push to any branch except dependabot/**
  Dev -> GH : git push
  opt not only paths-ignore files
    GH -> Pipe : push
  end
  opt branch main
    GH -> CodeQL : push
  end
  opt .devcontainer/** changed
    GH -> DevEnv : push
  end
end

group pull request
  Bot -> GH : open PR (or Developer)
  GH -> CodeQL : pull_request (base main)
  GH -> House : pull_request opened / assigned
end

group release (separate run)
  opt pipeline.yml on main and Semantic Release finds a release
    Pipe -> GH : create GitHub release (PAT)
    GH -> Rel : release created
    Rel -> Pages : deploy docs site
  end
end

group schedules (UTC)
  GH -> Pipe : Tuesday 01:00
  GH -> DevEnv : Tuesday 01:00
  GH -> CodeQL : Sunday 05:00
  GH -> House : daily 01:00, 05:30, 06:00
end
@enduml
```

## Troubleshooting and Important Conditions

- **Docs-only changes publish nothing.** `pipeline.yml` ignores pushes that only touch `**.md` or `docs/**`, so no release happens and the docs site stays as it was. The site is only rebuilt by `release.yml`, that is, with the next release. Changing `mkdocs.yml` together with the docs does start `pipeline.yml`, but a release still needs a `feat`, `fix` or `perf` commit.
- **Releases come only from `main`.** `release-code` is skipped on every other branch, and `.releaserc.js` lists only `main` as a release branch.
- **The scheduled run can release.** The Tuesday `schedule` run of `pipeline.yml` runs on `main`, so it releases any pending `feat` or `fix` commits.
- **The release hand-over needs the PAT.** If `GH_TOKEN_REPO_AND_PROJECT` is missing or expired, Semantic Release fails. A release created with `GITHUB_TOKEN` instead would not start `release.yml`.
- **`generate-docs` commits to feature branches too.** After a push to a feature branch, pull before pushing again, or the push is rejected.
- **A failing `molecule`, `molecule-cloud` or `generate-docs` job blocks the release.** `generate-docs` needs both Molecule jobs, and `release-code` needs `generate-docs`.
- **The release intro can be missing.** If the Copilot CLI produces no text (for example because the budget is exhausted), the release is published without it and the workflow still succeeds.
- **No concurrency control.** None of the workflows defines a `concurrency` group, so two quick pushes to `main` run two pipelines in parallel.
- **Cloud changes are not deployed by CI** (see [Cloud Deployment Pipeline](#cloud-deployment-pipeline)).
