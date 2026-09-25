# Omarchy in Virtual Machine - Setup Guide

This guide explains how to provision an Omarchy virtual machine. This covers a manual setup. For Vagrant, this guide need to be adopted.

- [ ] Run through the Omarchy setup wizard (hostname, user, disk encryption, etc.).
- [ ] Initialize SSH and other mandatory things using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/omarchy.sh | bash -`
- [ ] Initialize SSH and other mandatory things using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/virtual-machines/omarchy/bootstrap-vm.sh | bash -`
- [ ] Install machine using the Ansible configs from this repo
    - [ ] `mkdir -p ~/tmp && cd ~/tmp && git clone --recurse-submodules https://github.com/sommerfeld-io/configs-homelab.git && cd configs-homelab`
    - [ ] Playbook `virtual-machines/omarchy/playbook-provision.yml` (`task vm:omarchy:ansible:provision`)
    - [ ] Configure SSH keys on GitHub.com for the machine
    - [ ] Playbook `virtual-machines/omarchy/playbook-provision.yml` (`task ansible:omarchy:ansible:repositories`) 
