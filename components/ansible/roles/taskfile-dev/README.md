# Role: taskfile-dev

Install `task` command line tool from [Taskfile.dev](https://taskfile.dev).

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

| Variable             | Description |
|----------------------|-------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user). |
