# Role: Dashboards

This role provisions Grafana Cloud dashboards and folder structures using the Grafana API. It creates a hierarchical folder organization and imports dashboards from Grafana.com by their dashboard IDs. It also creates custom dashboards based on JSON definitions.

> **NOTE:** This role is designed to run on localhost to avoid creating folders and dashboards multiple times. it does not require elevated privileges.

All sensitive credentials are stored in an encrypted Ansible Vault file. The vault file is safe to commit to the repository.

## Required Variables

The following sensitive variables must be defined in `components/ansible/vars/grafana-vault.yml` (encrypted with Ansible Vault):

| Variable              | Description                                       |
|-----------------------|---------------------------------------------------|
| `grafana_com_api_key` | Grafana Cloud API key with dashboard permissions  |
| `grafana_com_url`     | The URL of the Grafana Cloud instance             |
