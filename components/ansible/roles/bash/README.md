# Role: Bash

Configures bash settings and create an SSH keypair.

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

| Variable             | Description |
|----------------------|-------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user). |
| `{{ ps1 }}`          | The bash prompt string. This variable is set in the host inventory. |
