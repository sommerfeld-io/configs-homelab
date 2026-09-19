# Ansible - Molecule Tests

[Molecule](https://docs.ansible.com/projects/molecule) tests the Ansible roles defined directly in this repository under `ansible/roles/`, applying them to disposable Docker containers (Ubuntu and Arch Linux) and asserting the expected result.

Scenarios are grouped by role group under `tests/molecule/{role-group}/molecule/default/`. Run them with `task molecule:test:<role-group>` (e.g. `task molecule:test:common`), or all of them at once with `task molecule:test`. The `molecule` job in the CI pipeline runs these tests automatically and gates the release stage.

## Out of scope: `ansible/roles/ansible-roles-collection`

The roles in `ansible/roles/ansible-roles-collection/` are a git submodule and are **not** tested here. That collection is its own repository with its own Molecule test suite, so testing it again from this repo would be redundant.
