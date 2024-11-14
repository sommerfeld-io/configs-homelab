# ansible-cli.sh

Command line interface to run Ansible playbooks.

## Overview

This Bash script allows to running Ansible playbooks. The script is designed to simplify the
management of Ansible playbooks.

To run playbooks successfully, make sure to run `ssh-copy-id <REMOTE_USER>@<REMOTE_HOST>.fritz.box`
first to ensure seamless connects to all remote machines. Run `ssh-copy-id <LOCAL_USER>@<LOCAL_HOST>.fritz.box`
for your local machine as well (if this machine is listed in the host inventory.). Otherwise Ansible might fail
when connecting to your local machine via its FQDN.

```bash
ssh-copy-id sebastian@caprica.fritz.box
ssh-copy-id sebastian@kobol.fritz.box
```

Ansible expects the user `sebastian` to be present on all nodes. This user is the default
user for each node (workstation, server and RasPi). Normally this user is created when
installing an operating system through its setup wizard. This scripts exits with `exitcode=8`
if this user does not exist.

Overall, this script is designed to simplify the management of Ansible playbooks by providing a
clean and automated environment for running them.

### Usage
The script does not accept any parameters.

**Important:** This script must run on the host machine, not in a Docker container. The script checks if the
user is `vscode` and exits with an error message if this is the case. This is mandatory because
the development container cannot connect to machines on the host network and therefore cannot
successfully run Ansible commands.

### Prerequisites
Before using this script, you need to ensure that Ansible is installed on the system which runs
the playbooks. The script assumes that the Docker engine is running, and the user has necessary
permissions to execute Docker commands.

## Ansible Playbooks
This script automatically detects all Ansible playbooks in the `components/homelab/src/main/ansible/playbooks`
folder.

### Playbook: `desktops-main.yml`
This Ansible playbook is designed to configure basic settings, directory structure, and
software packages for Ubuntu desktop machines. The playbook also includes some tasks that are
shared with other playbooks to ensure a consistent setup among all machines.

### Playbook: `desktops-steam.yml`
This Ansible playbook is designed to install Steam on Ubuntu desktop machines.

### Playbook: `raspi-main.yml`
This Ansible playbook is designed to configure basic settings, directory structure, and
software packages for Raspberry Pi machines. The playbook also includes some tasks that are
shared with other playbooks to ensure a consistent setup among all machines but uses a reduced tasks set.

## Index

* [title](#title)

### title

Write a title to stdout.

#### Arguments

* **$1** (String): The title to print

