# Ansible Playbook - Ping

This Ansible playbook performs a lightweight connectivity and Python execution check across all nodes in the home lab inventory. It is intended as a quick health check to verify that managed hosts are reachable and ready for further automation tasks.

## What it does

- **Node Reachability Check**: Connects to every configured host in the Ansible inventory
- **Ansible Ping Validation**: Executes `ansible.builtin.ping` to confirm remote module execution works
- **Fact Gathering**: Collects OS, network, and hardware facts from every reachable node

The playbook targets all inventory nodes to provide a simple, centralized operational readiness check for the full home lab.

To scan the network for devices and services (including devices outside the inventory), use the [Netaudit playbook](./netaudit.md).
