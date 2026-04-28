# GitHub Copilot Instructions

## Commit Messages: Conventional Commits

Always use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#summary) for every commit message.

**Format:** `<type>[optional scope]: <description>`

| Type | Effect | When to use |
|------|--------|-------------|
| `fix` | PATCH release | Patches a bug |
| `feat` | MINOR release | Introduces a new feature |
| `BREAKING CHANGE` footer | MAJOR release | Introduces a breaking API change |
| `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test` | No release | All other changes |

**Rules:**
- A scope may be added in parentheses for extra context: `feat(parser): add ability to parse arrays`
- Breaking changes must include `BREAKING CHANGE:` in the footer: `feat: drop support for Node 6`
- Commit message titles must also match the project pattern: `^(fix|feat|build|chore|ci|docs|style|refactor|perf|test)/[a-z0-9._-]+$`

Write commit messages using the Conventional Commits format, ensuring the header (`type(scope): summary`) is clear and descriptive, as it will be displayed on GitHub release pages and used for changelogs. Focus the header on user-visible, meaningful change descriptions and avoid vague wording. Always document breaking changes explicitly in the footer using `BREAKING CHANGE:` (do not use the `!` notation).

## Project Overview

Infrastructure-as-Code (IaC) repository managing homelab workstations, servers, and Raspberry Pi nodes. Primary automation tool is **Ansible**; all linters run in Docker via **go-task**.

- Docs: [docs/](../docs/) rendered with MkDocs (Material theme)
- Ansible roles live in `ansible/roles/ansible-roles-collection/` (git submodule)
- Encrypted secrets: `ansible/vars/vault.yml`, `ansible/vars/grafana-vault.yml` (Ansible Vault)
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
```

Use the [`lint-and-fix`](.github/skills/lint-and-fix/SKILL.md) skill to run linters and fix errors.

## Ansible Conventions

- **Playbooks:** `ansible/playbooks/*.yml` — one playbook per concern (e.g. `desktop.yml`, `grafana.yml`)
- **Roles:** `ansible/roles/ansible-roles-collection/{role-name}/` — each role has `tasks/`, optionally `defaults/`, `handlers/`, `files/`, `templates/`
- **Inventory:** `ansible/hosts.yml` — groups: `ubuntu_desktop`, `raspi`, `ollama`
- **Vars:** `ansible/vars/main.yml` (general), `raspi.yml`, `ubuntu.yml`; vault files for secrets
- Run `task lint` (includes `lint-ansible`) before committing any Ansible changes

## File & Folder Conventions

- Filenames: kebab-case enforced by ls-lint (`.ls-lint.yml`)
- Folder structure enforced by folderslint (`.folderslintrc`)
- YAML style enforced by yamllint (`.yamllint.yml`) — do **not** quote top-level `on:` keys in GitHub Actions workflows
- Markdown link validity enforced by lychee (`.lychee.toml`)
- Docs in `docs/` mirror the `ansible/` structure; update docs when adding playbooks or roles

## Testing

InSpec compliance profiles in `tests/inspec/{profile-name}/`. Run via `task inspec:run:<hostname>`.
