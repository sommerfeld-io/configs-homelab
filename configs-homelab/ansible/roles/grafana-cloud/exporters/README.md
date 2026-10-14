# Role: Grafana Cloud / Exporters

This role deploys and manages exporters that expose telemetry data for collection by Grafana Alloy. Currently it deploys [cAdvisor](https://github.com/google/cadvisor) as a Docker Compose service, which exposes container resource metrics (CPU, memory, network, filesystem) on port `9110`.

The compose file is copied to `{{ exporters_path }}` and the container is brought up with `pull: missing` so that the image is only pulled when not already present on the machine.

The compose file is static, so Dependabot can bump the cAdvisor image. The host address of port `9110` comes from a `.env` file next to it (`CADVISOR_BIND_ADDRESS`), which the role writes from `exporters_cadvisor_bind_address`. A change of the compose file restarts the stack. When the bind address in `.env` changes, compose up recreates the container with the new port binding, and the role asserts that the binding matches `exporters_cadvisor_bind_address`. The homelab nodes keep the default `0.0.0.0`, which publishes the port on IPv4 only (the earlier `9110:8080` also published `[::]:9110`). The DigitalOcean droplets set `127.0.0.1` in `configs-cloud/digital-ocean/ansible/vars/main.yml`, because they have a public IP and no firewall, and their Alloy scrapes `localhost:9110`.

## Default Variables

| Variable                          | Default                        | Description                                                  |
|-----------------------------------|--------------------------------|--------------------------------------------------------------|
| `exporters_path`                  | `/opt/grafana-cloud/exporters` | Path where the compose file and the `.env` file are deployed |
| `exporters_cadvisor_bind_address` | `0.0.0.0`                      | Host address cAdvisor's port `9110` is published on          |

## Required Variables

| Variable       | Description                                                          |
|----------------|----------------------------------------------------------------------|
| `default_user` | The user that owns the deploy directory and its files on the node    |
