# Role: Git Repositories

Clone Git repositories.

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

| Variable             | Description |
|----------------------|-------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user). |
| `{{ github }}`      | SSH Base-URL to clone repositories from GitHub. |
| `{{ repositories }}` | A list of Git repositories to clone. Each entry should be a dictionary with the following keys: `dest` (the destination directory to where the repository should be cloned), `org`, and `repo`. |
