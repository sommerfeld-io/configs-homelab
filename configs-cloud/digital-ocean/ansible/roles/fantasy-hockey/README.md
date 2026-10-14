# Role: Fantasy Hockey

This role deploys [Fantasy Hockey](https://github.com/sommerfeld-io/fantasy-hockey), a private NHL prediction-pool app, as a Docker Compose service behind an nginx reverse proxy. See the app's [documentation](https://github.com/sommerfeld-io/fantasy-hockey/blob/main/docs/index.md) for the full set of available configuration options. It runs on the DigitalOcean droplet through `configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml`, see `docs/cloud/digital-ocean/deployment.md`.

The tasks are split in three files:

- `tasks/user.yml` creates `default_user` in the `docker` group (`docker` role of the roles collection, only `50-user`) and writes its `.bashrc` with the prompt `fantasy_hockey_ps1` (`bash` role, only `10-bash-config`). The full `docker` role does not run: its `state: latest` install is not idempotent.
- `tasks/files.yml` writes the deploy directory: the compose file and nginx config are copied to `{{ fantasy_hockey_path }}`, the `.env` file is templated, and the data file is seeded.
- `tasks/main.yml` first asserts that `fantasy_hockey_volume_mount` is a mount point and that `fantasy_hockey_path` lies below it, before anything is written. It then includes `user.yml` and `files.yml`, brings the stack up as `default_user` with `pull: missing` (the image is only pulled when not already present), restarts it when the compose file, the nginx config or `.env` changed, and asserts that both containers run.

`user.yml` and `files.yml` need no Docker, so the Molecule scenario runs them alone.

nginx listens on port 80 and proxies to the app's port 8080, which is otherwise only reachable on the host's loopback interface. nginx answers `/metrics` with 404; Alloy scrapes the app on `localhost:8080/metrics`.

The compose file itself is static (not templated). Session-secret and SMTP configuration instead flow through a generated `.env` file (`${SESSION_SECRET}`, `${SMTP_HOST}`, `${SMTP_PORT}`, `${SMTP_USERNAME}`, `${SMTP_APP_PASSWORD}`), which `docker compose` loads automatically from the project directory - the same pattern the app's own repo uses for local development. `.env` has mode `0600`.

The initial `fantasy-hockey.yml` data file is seeded once from a template (player list, season and the regular-season prediction deadline come from this role's variables). A `stat` check gates the seeding task: once the file exists on the target, this role never touches it again on any later run - not its content, not its ownership or mode - regardless of how it has since diverged from the template. The app mutates this file at runtime via atomic write-and-rename, and the pool operator hand-edits it directly, so a playbook re-run must never overwrite live pool data. The data directory is owned by UID 1000 to match the image's non-root `fantasy-hockey` user.

## Default Variables

| Variable                                     | Default                                              | Description                                                                 |
|----------------------------------------------|------------------------------------------------------|-----------------------------------------------------------------------------|
| `fantasy_hockey_volume_mount`                | `/mnt/prod_fantasy_hockey_data`                      | Volume mount point; the role stops when it is not mounted                   |
| `fantasy_hockey_path`                        | `{{ fantasy_hockey_volume_mount }}/fantasy-hockey`   | Path where the compose file and data are deployed; must lie below the mount |
| `fantasy_hockey_season`                      | `2026-27`                                            | Season label written into the seeded data file                              |
| `fantasy_hockey_regular_season_deadline_utc` | `2026-10-24T23:59:00Z`                               | Deadline for the before-season prediction sets                              |
| `fantasy_hockey_ps1`                         | orange `ubuntu_server` prompt without `$(__git_ps1)` | Prompt written to the `.bashrc` of `default_user`                           |

## Required Variables

The secrets are not role defaults. `deploy-fantasy-hockey.yml` loads them from the Ansible Vault file `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml` (edit it with `task cloud:digital-ocean:vault:fantasy-hockey`). The Molecule scenario sets test values.

| Variable                        | Description                                                                         |
|---------------------------------|-------------------------------------------------------------------------------------|
| `default_user`                  | The user that owns the deploy directory and compose/nginx/env files and runs Docker |
| `fantasy_hockey_session_secret` | Signing key for session cookies                                                     |
| `fantasy_hockey_smtp_host`      | Outbound mail server                                                                |
| `fantasy_hockey_smtp_port`      | Outbound mail server port                                                           |
| `fantasy_hockey_smtp_username`  | SMTP username                                                                       |
| `fantasy_hockey_smtp_password`  | SMTP password                                                                       |
| `fantasy_hockey_players`        | Players seeded into the data file (list of `id`, `name`, `email`)                   |
