# OpenTofu - Grafana Cloud

This OpenTofu root module declares the Grafana Cloud Synthetic Monitoring checks for the public websites and their alert rules. The state is kept locally in `terraform.tfstate` (gitignored). The provider reads its Synthetic Monitoring access token from `GRAFANA_SM_ACCESS_TOKEN`.

Run it through go-task, e.g. `task grafana-cloud:plan`.

## Documentation

- [Synthetic Monitoring](../../docs/grafana-cloud/synthetic-monitoring.md): the managed checks, the access token, the tasks, how to add a check and what to do when the state is lost
