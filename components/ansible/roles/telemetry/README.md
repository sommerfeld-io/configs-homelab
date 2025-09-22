# Role: Telemetry

This stack installs and starts services for telemetry metrics collection.

With `tasks_from: main` this role installs / starts all exporters to expose metrics for the monitoring stack. This is intended to be used on all machines (RasPi and workstation).

With `tasks_from: monitoring-stack` this role installs / starts the main telemetry services (Prometheus, Grafana, Alertmanager). This is intended to be used on RasPi machines only - the `admin-pi`  in particular.

## Expected Variables

- `{{ ansible_user }}`: The user to install and configure for (typically the logged-in user).
