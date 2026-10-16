# Role: Fantasy Hockey

This role deploys [Fantasy Hockey](https://github.com/sommerfeld-io/fantasy-hockey), a private NHL prediction-pool app, as a Docker Compose service behind a Caddy reverse proxy that serves it over HTTPS at its domain. See the app's [documentation](https://github.com/sommerfeld-io/fantasy-hockey/blob/main/docs/index.md) for the full set of available configuration options. It runs on the DigitalOcean droplet through `configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml`, see `docs/cloud/digital-ocean/deployment.md`.

The tasks are split in four files:

- `tasks/user.yml` creates `default_user` in the `docker` group (`docker` role of the roles collection, only `50-user`) and writes its `.bashrc` with the prompt `fantasy_hockey_ps1` (`bash` role, only `10-bash-config`). The full `docker` role does not run: its `state: latest` install is not idempotent.
- `tasks/dns.yml` resolves `fantasy_hockey_domain` with `getent ahostsv4` and stops unless the addresses are exactly `fantasy_hockey_reserved_ip`: a second address fails too, because Let's Encrypt may validate against it. Its message names the domain, the addresses found, the expected IP, `docs/cloud/digital-ocean/domain.md` and the `getent` command to repeat the lookup on the droplet. Resolving at all is not enough: the `sommerfeld.app` wildcard answers every missing name.
- `tasks/files.yml` writes the deploy directory: the compose file is copied to `{{ fantasy_hockey_path }}`, the Caddyfile and the `.env` file are templated, Caddy's `caddy/data` and `caddy/config` folders are created (`0700`), the data file is seeded, and the `nginx/` folder of the former nginx proxy is deleted.
- `tasks/main.yml` first asserts that `fantasy_hockey_volume_mount` is a mount point and that `fantasy_hockey_path` lies below it, and includes `dns.yml`, before anything is written. It then includes `user.yml` and `files.yml`, brings the stack up as `default_user` with `pull: missing` (the image is only pulled when not already present) and `remove_orphans` (removes the former `fantasy-hockey-nginx` container), restarts it when the compose file, the Caddyfile or `.env` changed, and asserts that the app and Caddy containers run.

`dns.yml`, `user.yml` and `files.yml` need no Docker, so the Molecule scenario runs them alone.

Caddy listens on ports 80 and 443 (443/udp for HTTP/3) and serves only `fantasy_hockey_domain`. It gets a Let's Encrypt certificate for it, keeps it with the ACME account in `caddy/data` on the volume, so a replacement droplet reuses it, and redirects `http://` on the domain to `https://`. Every other name on port 80, the IP included, gets 404; `https://` on the IP fails the TLS handshake, because Caddy has no certificate for it. Caddy proxies to the app's port 8080 over the compose network; the app's port is otherwise only reachable on the host's loopback interface. Caddy answers `/metrics` (any case, extra slashes) with 404; Alloy scrapes the app on `localhost:8080/metrics`. Caddy writes its logs as JSON to stderr: an access log for the domain (none for the `http://` catch-all) and its own logs. Before a line is written, client IPs (`remote_ip`, `client_ip`) are masked to /24 for IPv4 and /48 for IPv6, by the site's `log` block for the access log and by the global `log` block for Caddy's own logs (proxy errors include the request), and the client-sent headers `X-Forwarded-For`, `X-Real-Ip` and `Forwarded`, which can carry the full IP, are deleted from the logged request, so visitors are not identifiable in Grafana Cloud. `Cookie` and `Authorization` values stay redacted (Caddy's default).

The compose file itself is static (not templated). Session-secret and SMTP configuration instead flow through a generated `.env` file (`${SESSION_SECRET}`, `${SMTP_HOST}`, `${SMTP_PORT}`, `${SMTP_USERNAME}`, `${SMTP_APP_PASSWORD}`), which `docker compose` loads automatically from the project directory - the same pattern the app's own repo uses for local development. `.env` has mode `0600`.

The initial `fantasy-hockey.yml` data file is seeded once from a template (player list, season and the regular-season prediction deadline come from this role's variables). A `stat` check gates the seeding task: once the file exists on the target, this role never touches it again on any later run - not its content, not its ownership or mode - regardless of how it has since diverged from the template. The app mutates this file at runtime via atomic write-and-rename, and the pool operator hand-edits it directly, so a playbook re-run must never overwrite live pool data. The data directory is owned by UID 1000 to match the image's non-root `fantasy-hockey` user.

## Default Variables

| Variable                                     | Default                                              | Description                                                                 |
|----------------------------------------------|------------------------------------------------------|-----------------------------------------------------------------------------|
| `fantasy_hockey_volume_mount`                | `/mnt/prod_fantasy_hockey_data`                      | Volume mount point; the role stops when it is not mounted                   |
| `fantasy_hockey_path`                        | `{{ fantasy_hockey_volume_mount }}/fantasy-hockey`   | Path where the compose file and data are deployed; must lie below the mount |
| `fantasy_hockey_domain`                      | `fantasy-hockey.prod.do.sommerfeld.app`              | The only name Caddy serves; the playbook derives it from the droplet name   |
| `fantasy_hockey_season`                      | `2026-27`                                            | Season label written into the seeded data file                              |
| `fantasy_hockey_regular_season_deadline_utc` | `2026-10-24T23:59:00Z`                               | Deadline for the before-season prediction sets                              |
| `fantasy_hockey_ps1`                         | orange `ubuntu_server` prompt without `$(__git_ps1)` | Prompt written to the `.bashrc` of `default_user`                           |

## Required Variables

The secrets and the reserved IP are not role defaults. `deploy-fantasy-hockey.yml` reads the reserved IP from the metadata service and loads the secrets from the Ansible Vault file `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml` (edit it with `task cloud:digital-ocean:ansible:vault:fantasy-hockey`). The Molecule scenario sets test values.

| Variable                        | Description                                                                                                        |
|---------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `default_user`                  | The user that owns the deploy directory and compose/Caddy/env files and runs Docker                                |
| `fantasy_hockey_reserved_ip`    | The droplet's reserved IP the domain must resolve to; the playbook reads it from the DigitalOcean metadata service |
| `fantasy_hockey_session_secret` | Signing key for session cookies                                                                                    |
| `fantasy_hockey_smtp_host`      | Outbound mail server                                                                                               |
| `fantasy_hockey_smtp_port`      | Outbound mail server port                                                                                          |
| `fantasy_hockey_smtp_username`  | SMTP username                                                                                                      |
| `fantasy_hockey_smtp_password`  | SMTP password                                                                                                      |
| `fantasy_hockey_players`        | Players seeded into the data file (list of `id`, `name`, `email`)                                                  |
