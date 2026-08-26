# Ansible Playbook - Office

This Ansible playbook performs comprehensive setup and configuration of ubuntu VMs on the office workstations, transforming them into fully-featured development and administrative machines.

The playbook handles both system-level configuration requiring elevated privileges and user-specific customizations to create a standardized, secure, and productive desktop environment.

> **CAUTION:** Avoid running this playbook on other machines. Since it is based on [playbook `desktop.yml`](desktop.md), this playbook should not cause any trouble. But since this playbook targetse `localhost`, it is advised to not run this on other machines. 

## What it does

- **Security Hardening**: Applies security configurations and hardening measures to protect the system
- **Development Environment**: Installs and configures essential development tools
- **Shell Enhancement**: Sets up improved Bash configurations
- **Task Automation**: Installs utilities for simplified task execution and sets up automated cron jobs
- **File System Management**: Creates standardized directory structures and file system configurations
- **Package Management**: Installs essential system packages and Ubuntu-specific software repositories

The playbook targets desktop workstations to establish a complete, standardized development and administrative environment suitable for home lab operations and software development activities.

> **NOTE:** This playbook is based on [playbook `desktop.yml`](desktop.md), but lacks the virtualization with WMs and Vagrant. Docker however is part of the setup.

## How to run the playbook for the first time

Running the playbook for the first time on a fresh VM needs some special steps because the VM does not yet have any SSH key set up and configured with GitHub.com. So we cannot clone any Git repo or submodule via SSH.

The following steps are required for the initial bootstrapping of the VM.

```bash
sudo apt update
sudo apt install open-vm-Tools -y
sudo apt install curl -y
sudo apt install vim -y

curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/install-basics.sh | bash 

curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/ssh-server.sh | bash -

cd /tmp
git clone https://github.com/sommerfeld-io/configs-homelab.git

cd configs-homelab
git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --init --recursive

GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf  GIT_CONFIG_VALUE_0=git@github.com:  task ansible:office

cd ..
rm -rf configs-homelab
```
