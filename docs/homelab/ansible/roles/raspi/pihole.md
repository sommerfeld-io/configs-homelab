# Role: RasPi / Pi-hole

This role deploys [Pi-hole](https://pi-hole.net) as a Docker Compose service, providing network-wide ad blocking and DNS resolution for the home lab. See the [`pi-hole/docker-pi-hole`](https://github.com/pi-hole/docker-pi-hole/blob/master/README.md) documentation for the full set of available configuration options.

The compose file is copied to `{{ pihole_path }}` and the container is brought up with `pull: missing` so the image is only pulled when not already present.

Before the stack starts, the role frees host port 53 by disabling `systemd-resolved`'s DNS stub listener (`DNSStubListener=no` in `/etc/systemd/resolved.conf`) and re-pointing `/etc/resolv.conf` at the non-stub resolver — otherwise Pi-hole fails to bind port 53 with "address already in use". This is persistent across reboots since it's a config file change, not a runtime toggle.

Pi-hole's DNS rate limiting is disabled (`FTLCONF_dns_rateLimit_count: 0`). All clients reach Pi-hole through the FRITZ!Box gateway (`192.168.178.1`), so Pi-hole sees the router as its only client, and a per-client rate limit would answer the whole network with `REFUSED` once it trips. Pi-hole has no per-client exemption for rate limiting, so a global switch-off is the only option. The router is deliberately not exempted from blocklists, because that would turn ad blocking off for every client.

## Default Variables

| Variable            | Default       | Description                             |
|---------------------|---------------|-----------------------------------------|
| `pihole_path` | `/opt/pihole` | Path where the compose file is deployed |

## Required Variables

| Variable       | Description                                                          |
|----------------|----------------------------------------------------------------------|
| `default_user` | The user that owns the deploy directory and compose file on the node |
