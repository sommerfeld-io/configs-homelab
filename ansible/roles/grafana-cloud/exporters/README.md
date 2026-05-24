# Role: Grafana Cloud / Exporters

This role deploys and manages exporters that expose telemetry data for collection by Grafana Alloy. Currently it deploys [cAdvisor](https://github.com/google/cadvisor) as a Docker Compose service, which exposes container resource metrics (CPU, memory, network, filesystem) on port `9110`.

The compose file is copied to `/opt/grafana-cloud/exporters/` and the container is brought up with `pull: missing` so that the image is only pulled when not already present on the machine.

## Required Variables

| Variable       | Description                                                          |
|----------------|----------------------------------------------------------------------|
| `default_user` | The user that owns the deploy directory and compose file on the node |
