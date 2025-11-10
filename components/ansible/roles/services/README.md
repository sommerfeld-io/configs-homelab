# Role: Services

This stack installs and starts services for all workstations and Raspberry Pi nodes. The corresponding repositories are updated to the latest version.

- With `tasks_from: main` this role installs / starts all exporters to expose common services. This is intended to be used on all machines (RasPi and workstation).
- With `tasks_from: admin-pi` this role installs / starts the services and is intended to be used on the `admin-pi` only.

## Expected Variables

| Variable             | Description |
|----------------------|-------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user). |
