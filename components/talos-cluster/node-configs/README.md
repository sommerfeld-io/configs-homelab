# Talos Node Configs

See `docs/nodes/talos/installation.md` for more information on how to generate the config files.

## About the `talos.config.sh` script

This script is written in Bash rather than being part of an Ansible playbook for several reasons:

### One-time Setup

The cluster setup is a one-time operation. Ansible is typically used for tasks that need to be repeated or managed over time. Running this setup repeatedly with Ansible could lead to issues, such as overwriting existing configurations or causing conflicts with certificates and PKI.

### Open Question: Adding New Nodes

To add new nodes to an existing cluster, we might need to rework this script or create a second script. Here are some considerations:

1. **Separate Script for Adding Nodes**: Create a new script specifically for adding new nodes. This script would generate and apply configurations only for the new nodes without affecting the existing cluster setup.
1. **Modify Existing Script**: Enhance the current script to handle both initial setup and adding new nodes. This could involve adding logic to detect whether the cluster is already set up and then only generating configurations for new nodes. Alternatively a select menu or script arguments could be used to differentiate between initial setup and adding new nodes.
