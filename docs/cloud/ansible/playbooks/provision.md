# Ansible Playbook - Provision

This Ansible playbook provisions all Ubuntu droplets that the dynamic inventory finds through the DigitalOcean API. It first waits until a new droplet accepts SSH and cloud-init is done, then configures the droplet:

- **Time zone:** `Europe/Berlin`
- **Shell and tools:** the root prompt and the basic command line tools, from the homelab roles collection
- **Docker:** from the Docker apt repository
- **Swap:** a 1 GiB swap file, see the [Swap role](../roles/swap.md)
- **cAdvisor:** the [Grafana Cloud / Exporters](../../../homelab/ansible/roles/grafana-cloud/exporters.md) role of the homelab, bound to `127.0.0.1:9110` on the droplet
- **Grafana Alloy:** the [Grafana Cloud / Alloy](../../../homelab/ansible/roles/grafana-cloud/alloy.md) role of the homelab with the cloud config and the labels `environment` and `stage`
- **Login banner:** see the [MOTD role](../roles/motd.md)

Run it with `task cloud:digital-ocean:ansible:provision`. It asks for the vault password. A second run reports no change, unless a new release of Docker or a basic tool was installed. See [Provisioning](../../digital-ocean/provisioning.md) for the inventory, the role order and the Alloy labels.
