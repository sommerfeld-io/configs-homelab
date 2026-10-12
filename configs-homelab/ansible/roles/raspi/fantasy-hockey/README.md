# Role: RasPi / Fantasy Hockey

This role deploys [Fantasy Hockey](https://github.com/sommerfeld-io/fantasy-hockey), a private NHL prediction-pool app, as a Docker Compose service behind an nginx reverse proxy. See the app's [documentation](https://github.com/sommerfeld-io/fantasy-hockey/blob/main/docs/index.md) for the full set of available configuration options.

The compose file and nginx config are copied to `{{ raspi_fantasy_hockey_path }}`, and the stack is brought up with `pull: missing` so the image is only pulled when not already present. nginx listens on port 80 and proxies to the app's port 8080, which is otherwise only reachable on the host's loopback interface.

The compose file itself is static (not templated). Session-secret and SMTP configuration instead flow through a generated `.env` file (`${SESSION_SECRET}`, `${SMTP_HOST}`, `${SMTP_PORT}`, `${SMTP_USERNAME}`, `${SMTP_APP_PASSWORD}`), which `docker compose` loads automatically from the project directory - the same pattern the app's own repo uses for local development.

The initial `fantasy-hockey.yml` data file is seeded once from a template (player list, season and the regular-season prediction deadline come from this role's variables). A `stat` check gates the seeding task: once the file exists on the target, this role never touches it again on any later run - not its content, not its ownership or mode - regardless of how it has since diverged from the template. The app mutates this file at runtime via atomic write-and-rename, and the pool operator hand-edits it directly, so a playbook re-run must never overwrite live pool data. The data directory is owned by UID 1000 to match the image's non-root `fantasy-hockey` user.

## Default Variables

| Variable                                           | Default                      | Description                                                        |
|----------------------------------------------------|------------------------------|--------------------------------------------------------------------|
| `raspi_fantasy_hockey_path`                        | `/opt/fantasy-hockey`        | Path where the compose file and data are deployed                  |
| `raspi_fantasy_hockey_session_secret`              | (generated random value)     | Signing key for session cookies                                    |
| `raspi_fantasy_hockey_smtp_host`                   | `smtp.example.com`           | Placeholder outbound mail server - replace before relying on email |
| `raspi_fantasy_hockey_smtp_port`                   | `587`                        | Placeholder outbound mail server port                              |
| `raspi_fantasy_hockey_smtp_username`               | `fantasy-hockey@example.com` | Placeholder SMTP username                                          |
| `raspi_fantasy_hockey_smtp_password`               | `changeme-smtp-app-password` | Placeholder SMTP password                                          |
| `raspi_fantasy_hockey_season`                      | `2026-27`                    | Season label written into the seeded data file                     |
| `raspi_fantasy_hockey_regular_season_deadline_utc` | `2026-10-24T23:59:00Z`       | Deadline for the before-season prediction sets                     |
| `raspi_fantasy_hockey_players`                     | basti, sadl, tobbi           | Players seeded into the data file                                  |

## Required Variables

| Variable       | Description                                                          |
|----------------|------------------------------------------------------------------------|
| `default_user` | The user that owns the deploy directory and compose/nginx/env files on the node |
