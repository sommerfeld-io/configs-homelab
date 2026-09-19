# Role: RasPi / Pi-hole

This role deploys [Pi-hole](https://pi-hole.net) as a Docker Compose service, providing network-wide ad blocking and DNS resolution for the home lab. See the [`pi-hole/docker-pi-hole`](https://github.com/pi-hole/docker-pi-hole/blob/master/README.md) documentation for the full set of available configuration options.

The compose file is copied to `{{ raspi_pihole_path }}` and the container is brought up with `pull: missing` so the image is only pulled when not already present.

## Default Variables

| Variable            | Default       | Description                             |
|---------------------|---------------|-----------------------------------------|
| `raspi_pihole_path` | `/opt/pihole` | Path where the compose file is deployed |

## Required Variables

| Variable       | Description                                                          |
|----------------|----------------------------------------------------------------------|
| `default_user` | The user that owns the deploy directory and compose file on the node |
