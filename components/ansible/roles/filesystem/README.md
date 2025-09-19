# Role: Filesystem

Configures basic filesystem structure. Create directories and file and set permissions.

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

- `{{ ansible_user }}`: The user to configure for (typically the logged-in user).
- `{{ dir_work }}`: Workspace directory.
- `{{ dir_repos }}`: Directory for git repositories.
- `{{ dir_repos_sommerfeld_io }}`: Directory for GitHub repositories under the `sommerfeld-io` organization.
- `{{ dir_repos_sommerfeld_io_archive }}`: Directory for GitHub repositories archive under the `sommerfeld-io-archive` organization.
- `{{ dir_repos_sebastian_sommerfeld_io }}`: Directory for GitHub repositories under the `sebastian-sommerfeld-io` user space.
