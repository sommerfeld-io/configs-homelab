# ansible-cli.sh

Command line interface to run Ansible playbooks.

## Overview

This Bash script allows to running Ansible playbooks. The script is designed to simplify the
management of Ansible playbooks.

The script uses a Docker container to run Ansible, ensuring that your system remains clean and
free from dependencies. The Docker container is pre-configured with Ansible and all required
dependencies.

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

### Prerequisites
Before using this script, you need to ensure that Docker 24.0.6 or greater is installed on the
system which runs the playbooks. The script assumes that the Docker engine is running, and the
user has necessary permissions to execute Docker commands.

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

### Playbook: `update-upgrade.yml`
This Ansible playbook is designed to update all packages to their latest version and perform an aptitude
safe-upgrade on Ubuntu and RaspberryPi OS machines (both are Debian-based).

## Index

* [title](#title)
* [invoke](#invoke)
* [ansible](#ansible)
* [ansible-playbook](#ansible-playbook)

### title

Write a title to stdout.

#### Arguments

* **$1** (String): The title to print

### invoke

Wrapper function to encapsulate ansible in a docker container using the
[cytopia/ansible](https://hub.docker.com/r/cytopia/ansible) image.

Ansible runs in Docker as non-root user (the current user from the host is used inside the container).
Filesystem dependencies are mounted into the container to ensure the user inside the container shares
all relevant information with the user from the host.

The current working directory is mounted into the container and selected as working directory so that
all file of the project are available. Paths are preserved.

#### Arguments

* **...** (String): The ansible commands (1-n arguments) - $1 is mandatory

#### Exit codes

* **8**: If param with ansible command is missing

### ansible

Facade to map `ansible` command. The actual Ansible execution is delegated to
Ansible running in a Docker container.

#### Arguments

* **...** (String): The ansible-playbook commands (1-n arguments) - $1 is mandatory

### ansible-playbook

Facade to map `ansible-playbook` command. The actual Ansible execution is delegated to
Ansible running in a Docker container.

#### Arguments

* **...** (String): The ansible-playbook commands (1-n arguments) - $1 is mandatory
