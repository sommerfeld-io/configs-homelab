# Role: VSCode

With `tasks_from: main` this role installs VSCode.

With `tasks_from: plugins` this role installs a set of useful plugins. This should not be run as `root`.

This role is intended to be used on Ubuntu Desktop machines.

## Expected Variables

- `{{ ansible_user }}`: The user to install and configure for (typically the logged-in user).
