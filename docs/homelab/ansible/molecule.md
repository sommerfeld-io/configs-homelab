# Ansible - Molecule Tests

[Molecule](https://docs.ansible.com/projects/molecule) tests the Ansible roles defined directly in this repository under `configs-homelab/ansible/roles/`, applying them to disposable Docker containers (Ubuntu and Arch Linux) and asserting the expected result.

Scenarios are grouped by role group under `configs-homelab/tests/molecule/{role-group}/molecule/default/`. Run them with `task homelab:molecule:test:<role-group>` (e.g. `task homelab:molecule:test:common`), or all of them at once with `task homelab:molecule:test`. `.github/workflows/assets/find-molecule.sh` lists every folder below `configs-homelab/` with a tracked `molecule/default/molecule.yml`; `task homelab:molecule:test` and the `molecule` job in the CI pipeline both run that list, so a new role group needs no task or matrix entry. The job gates the release stage.

## Out of scope: `configs-homelab/ansible/roles/ansible-roles-collection`

The roles in `configs-homelab/ansible/roles/ansible-roles-collection/` are a git submodule and are **not** tested here. That collection is its own repository with its own Molecule test suite, so testing it again from this repo would be redundant.

## Cloud roles

The roles the DigitalOcean droplet runs (the cloud roles under `configs-cloud/digital-ocean/ansible/roles/` and the fleet Alloy role with the cloud template) have their own scenarios under `configs-cloud/digital-ocean/tests/molecule/`, run with `task cloud:molecule:test` and the `molecule-cloud` CI job. See [Cloud - Digital Ocean / Tests](../../cloud/digital-ocean/tests.md).
