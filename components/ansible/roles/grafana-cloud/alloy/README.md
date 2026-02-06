# Role: Alloy

This role deploys and starts Grafana Alloy to collect telemetry data and push it to Grafana Cloud. Alloy runs on port 12321.

- With `tasks_from: main` this role installs and starts Grafana Alloy on all machines (RasPi and workstation).
- With `tasks_from: admin-pi` this role installs and starts Grafana Alloy specifically on the `admin-pi`.

## Expected Variables

| Variable                  | Description                                                                       |
|---------------------------|-----------------------------------------------------------------------------------|
| `{{ ansible_user }}`      | The user to install and configure for (typically the logged-in user).             |
| `{{ grafana_cloud_dir }}` | The folder to install all Grafana Cloud components in (e.g. `/opt/grafana-cloud`) |

## Optional Variables

The following variables are optional and have default values:

| Variable          | Description         | Default |
|-------------------|---------------------|---------|
| `{{ alloy_dir }}` | Subfolder for Alloy | `alloy` |
