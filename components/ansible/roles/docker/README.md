# Role: Docker

With `tasks_from: main` this role installs and configures Docker, a popular containerization platform. This should be run as `root`.

With `tasks_from: scout` this role installs and configures Docker Scout, a tool for managing and securing container images. This should be run after Docker is installed and not as `root`.

This role is intended to be used on all machines (RasPi and workstation).

## Expected Variables

- `{{ ansible_user }}`: The user to install and configure for (typically the logged-in user).
