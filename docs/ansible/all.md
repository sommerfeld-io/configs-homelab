# Ansible Playbook - All

This Ansible playbook orchestrates a complete provisioning of all nodes in the home lab environment. It imports and executes all relevant sub-playbooks in sequence to ensure consistent configuration across all managed systems.

- [Include Grafana Playbook to provision desktop workstations on the homelab](./desktop.md)
- [Include Grafana Playbook to provision RasPi nodes on the homelab](./raspi.md)
- [Include Grafana Playbook to provision nodes on the homelab for use with Grafana Cloud](./grafana.md) (install agents)
- [Include Grafana Playbook to clone repositories on the homelab nodes](./repositories.md)
- [Include Grafana Playbook to clean up the homelab nodes from old files, etc.](./cleanup.md)

The playbook targets both Ubuntu workstations and Raspberry Pi nodes, establishing a fully configured and standardized infrastructure with all necessary services, monitoring, and security configurations in place.
