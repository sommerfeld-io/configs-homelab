# Role: taskfile-dev

Copy `task`-related files and config like a `taskfile.yml`.

The role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

| Variable             | Description                                                          |
|----------------------|----------------------------------------------------------------------|
| `{{ ansible_user }}` | The user to install and configure for (typically the logged-in user) |
