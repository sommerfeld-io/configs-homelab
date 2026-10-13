# AI Agent Instructions

## Commit Messages: Conventional Commits

Always use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#summary) for every commit message.

**Format:** `<type>(optional scope): <description>`

| Type                                                                | Effect        | When to use                      |
|---------------------------------------------------------------------|---------------|----------------------------------|
| `fix`                                                               | PATCH release | Patches a bug                    |
| `feat`                                                              | MINOR release | Introduces a new feature         |
| `BREAKING CHANGE` footer                                            | MAJOR release | Introduces a breaking API change |
| `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test` | No release    | All other changes                |

**Rules:**

- A scope may be added in parentheses for extra context: `feat(parser): add ability to parse arrays`. A scope may not be with a slash (`/`).
- Breaking changes must include `BREAKING CHANGE:` in the footer: `feat: drop support for Node 6`
- Commit message titles must also match the project pattern: `^(fix|feat|build|chore|ci|docs|style|refactor|perf|test)(\([a-z0-9._-]+\))?: .+$`. Titles using a slash instead of a colon (e.g. `chore/bump-deps`) are forbidden — always use `chore(bump-deps): ...` or `chore: ...`.

Write commit messages using the Conventional Commits format, ensuring the header (`type(scope): summary`) is clear and descriptive, as it will be displayed on GitHub release pages and used for changelogs. Focus the header on user-visible, meaningful change descriptions and avoid vague wording. Always document breaking changes explicitly in the footer using `BREAKING CHANGE:` (do not use the `!` notation).

## Project Overview

Infrastructure-as-Code (IaC) repository managing homelab workstations, servers, and Raspberry Pi nodes. Primary automation tool is **Ansible**; all linters run in Docker via **go-task**.

- Docs: [docs/](../docs/) rendered with MkDocs (Material theme)
- Ansible roles live in `configs-homelab/ansible/roles/ansible-roles-collection/` (git submodule)
- Encrypted secrets: `configs-homelab/ansible/vars/vault.yml`, `configs-homelab/ansible/vars/grafana-vault.yml` (Ansible Vault)
- Target nodes: `*.fritz.box` workstations and `pi*.fritz.box` Raspberry Pi nodes

## Key Commands

```bash
task lint                   # Run all linters (yaml, workflows, filenames, folders, ansible, markdown-links, alloy-config)
task cleanup                # Clean dev environment
task docs:run               # Start MkDocs dev server
task docs:generate          # Regenerate docs (copies index.md → README.md etc.)
# Ansible playbooks require host credentials and SSH access
task ansible:ping           # Connectivity check
task ansible:all            # Full provisioning
task inspec:check           # Vendor & validate InSpec compliance profiles
task molecule:test          # Run all Molecule scenarios (role groups) end-to-end
```

Use the [`lint-and-fix`](.github/skills/lint-and-fix/SKILL.md) skill to run linters and fix errors.

## Ansible Conventions

- **Playbooks:** `configs-homelab/ansible/playbooks/*.yml` - one playbook per concern (e.g. `desktop.yml`, `grafana-agents.yml`)
- **Roles:** `configs-homelab/ansible/roles/ansible-roles-collection/{role-name}/` - each role has `tasks/`, optionally `defaults/`, `handlers/`, `files/`, `templates/`
- **Inventory:** `configs-homelab/ansible/hosts.yml` - groups: `ubuntu_desktop`, `raspi`, `ollama`
- **Vars:** `configs-homelab/ansible/vars/main.yml` (general), `raspi.yml`, `ubuntu.yml`; vault files for secrets
- Run `task lint` (includes `lint-ansible`) before committing any Ansible changes

## File & Folder Conventions

- Filenames: kebab-case enforced by ls-lint (`.ls-lint.yml`)
- Folder structure enforced by folderslint (`.folderslintrc`)
- YAML style enforced by yamllint (`.yamllint.yml`) - do **not** quote top-level `on:` keys in GitHub Actions workflows
- Markdown link validity enforced by lychee (`.lychee.toml`)
- Docs in `docs/` mirror the `configs-homelab/ansible/` structure; update docs when adding playbooks or roles

## Testing

- **InSpec:** compliance profiles in `configs-homelab/tests/inspec/{profile-name}/`. Run via `task inspec:run:<hostname>`.
- **Molecule rule:** a new Ansible role in this repo (local homelab roles under `configs-homelab/ansible/roles/` and cloud roles under `configs-cloud/*/ansible/roles/`) is not done without a Molecule scenario. Roles in the `ansible-roles-collection` submodule are tested in the submodule, not here.
- **Molecule (homelab):** tests the local Ansible roles under `configs-homelab/ansible/roles/` (not the submodule) in Docker, without needing real hosts.
    - Scenarios are grouped by role group under `configs-homelab/tests/molecule/{role-group}/molecule/default/` (e.g. `common`), each defining `converge.yml` (applies the roles), `verify.yml` (asserts the result), and `molecule.yml` (points `ANSIBLE_ROLES_PATH` at the roles under test).
    - Shared platform/driver config lives in `configs-homelab/tests/molecule/base.yml` (Docker driver, Ubuntu + Arch Linux targets); shared OS bootstrapping (installing python3, creating the test user) lives in `configs-homelab/tests/molecule/prepare.yml`.
    - Run a single role group with `task molecule:test:<role-group>` (e.g. `task molecule:test:common`), or all of them with `task molecule:test`.
    - Runs automatically in CI (`.github/workflows/pipeline.yml`, `molecule` job) after linting and InSpec checks, and gates the release stage.
    - To test a new role group, add `configs-homelab/tests/molecule/{role-group}/molecule/default/{converge,verify}.yml`, a `molecule.yml` following the `common` example, and a corresponding `test:{role-group}` task in `configs-homelab/tests/molecule/taskfile.yml`.
- **Molecule (cloud):** tests the roles the DigitalOcean droplet runs, one scenario per role under `configs-cloud/digital-ocean/tests/molecule/{role}/molecule/default/` (`motd`, and `alloy` for the fleet Alloy role with the cloud template). `swap` has no scenario: `swapon` needs a privileged container.
    - Shared config: `base.yml` (one plain `ubuntu:26.04` platform, unprivileged, no systemd) and `prepare.yml` (packages the droplet image ships, the `docker` group, a `systemctl` stub). Never make a test container privileged, run systemd as PID 1 or mount host paths: the host rebooted during every run of a privileged systemd container.
    - Run one scenario with `task molecule-cloud:test:<role>`, or all with `task molecule-cloud:test`. CI runs them in the `molecule-cloud` job, which gates the docs and release stages like `molecule`.
    - To test a new cloud role, add `{role}/molecule/default/{molecule,converge,verify}.yml` following the `motd` example, a `test:{role}` task in `configs-cloud/digital-ocean/tests/molecule/taskfile.yml`, and the role to the `molecule-cloud` matrix in `pipeline.yml`.

@AGENTS.md
