# Role: Cron

With `tasks_from: main` this role configures global cron settings.

With `tasks_from: jobs` this role configures cron jobs for the user.

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

| Variable             | Description |
|----------------------|-------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user). |
