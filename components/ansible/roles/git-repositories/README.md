# Role: Git Repositories

Clone Git repositories.

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

- `{{ ansible_user }}`: The user to install for (typically the logged-in user).
- `{{ github }}`: SSH Base-URL to clone repositories from GitHub.
- `{{ repositories }}`: A list of Git repositories to clone. Each entry should be a dictionary with the following keys:
    - `dest`: The destination directory where the repository should be cloned.
    - `org`: The GitHub organization or user name (e.g., `"sommerfeld-io"`).
    - `repo`: The repository name (e.g., `"configs-homelab"`).
- `{{ dir_repos_sommerfeld_io }}`: The base directory for cloning repositories from the "sommerfeld-io" organization.
- `{{ dir_repos_sebastian_sommerfeld_io }}`: The base directory for cloning repositories from the "sebastian-sommerfeld-io" user space.
