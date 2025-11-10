# Role: Virtualization

This role installs and configures Virtualbox and Vagrant including all dependencies and relevant plugins.

This role is intended to be used on Ubuntu Desktop machines.

## Expected Variables

| Variable             | Description |
|----------------------|-------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user). |
