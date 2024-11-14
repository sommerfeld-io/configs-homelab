#!/bin/bash
# @file ansible-cli.sh
# @brief Command line interface to run Ansible playbooks.
# @description
#   This Bash script allows to running Ansible playbooks. The script is designed to simplify the
#   management of Ansible playbooks.
#
#   To run playbooks successfully, make sure to run `ssh-copy-id <REMOTE_USER>@<REMOTE_HOST>.fritz.box`
#   first to ensure seamless connects to all remote machines. Run `ssh-copy-id <LOCAL_USER>@<LOCAL_HOST>.fritz.box`
#   for your local machine as well (if this machine is listed in the host inventory.). Otherwise Ansible might fail
#   when connecting to your local machine via its FQDN.
#
#   ```bash
#   ssh-copy-id sebastian@caprica.fritz.box
#   ssh-copy-id sebastian@kobol.fritz.box
#   ```
#
#   Ansible expects the user `sebastian` to be present on all nodes. This user is the default
#   user for each node (workstation, server and RasPi). Normally this user is created when
#   installing an operating system through its setup wizard. This scripts exits with `exitcode=8`
#   if this user does not exist.
#
#   Overall, this script is designed to simplify the management of Ansible playbooks by providing a
#   clean and automated environment for running them.
#
#   ### Usage
#   The script does not accept any parameters.
#
#   **Important:** This script must run on the host machine, not in a Docker container. The script checks if the
#   user is `vscode` and exits with an error message if this is the case. This is mandatory because
#   the development container cannot connect to machines on the host network and therefore cannot
#   successfully run Ansible commands.
#
#   ### Prerequisites
#   Before using this script, you need to ensure that Ansible is installed on the system which runs
#   the playbooks. The script assumes that the Docker engine is running, and the user has necessary
#   permissions to execute Docker commands.
#
#   ## Ansible Playbooks
#   This script automatically detects all Ansible playbooks in the `components/homelab/src/main/ansible/playbooks`
#   folder.
#
#   ### Playbook: `desktops-main.yml`
#   This Ansible playbook is designed to configure basic settings, directory structure, and
#   software packages for Ubuntu desktop machines. The playbook also includes some tasks that are
#   shared with other playbooks to ensure a consistent setup among all machines.
#
#   ### Playbook: `desktops-steam.yml`
#   This Ansible playbook is designed to install Steam on Ubuntu desktop machines.
#
#   ### Playbook: `raspi-main.yml`
#   This Ansible playbook is designed to configure basic settings, directory structure, and
#   software packages for Raspberry Pi machines. The playbook also includes some tasks that are
#   shared with other playbooks to ensure a consistent setup among all machines but uses a reduced tasks set.


if [ "$USER" == "vscode" ]; then
  echo "[ERROR] You are running the script as the user: vscode"
  echo "[ERROR] That means you are running the script in a development container"
  echo "[ERROR] Cannot run Ansible commands from development container"
  echo "[ERROR] Cannot connect to nodes on the host network"
  echo "[ERROR] Please run the script on your local machine"
  exit 8
fi


set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly ANSIBLE_USER="sebastian"


# @description Write a title to stdout.
#
# @arg $1 String The title to print
function title() {
  if [ -z "$1" ]; then
    echo -e "$LOG_ERROR No title passed"
    exit 8
  fi

  echo -e "$LOG_INFO ------------------------------------------"
  echo -e "$LOG_INFO     $1"
  ansible --version
  echo -e "$LOG_INFO ------------------------------------------"
}


title 'Ansible CLI'

(
  cd ansible || exit

  if ! id "$ANSIBLE_USER" &>/dev/null; then
    echo -e "$LOG_ERROR +-----------------------------------------------------------------------------+"
    echo -e "$LOG_ERROR |                                                                             |"
    echo -e "$LOG_ERROR |    ANSIBLE USER NOT FOUND !!!                                               |"
    echo -e "$LOG_ERROR |                                                                             |"
    echo -e "$LOG_ERROR |    Ansible expects the user ${P}${ANSIBLE_USER}${D} to be present on all nodes.           |"
    echo -e "$LOG_ERROR |    This user is the default user for each node (workstation and RasPi).     |"
    echo -e "$LOG_ERROR |    Normally this user is created from the setup wizard.                     |"
    echo -e "$LOG_ERROR |                                                                             |"
    echo -e "$LOG_ERROR +-----------------------------------------------------------------------------+"
    echo -e "$LOG_ERROR exit" && exit 8
  fi


  echo -e "$LOG_INFO Select playbook"
  select playbook in playbooks/*.yml; do
    echo -e "$LOG_INFO Run $P$playbook$D"
    ansible-playbook "$playbook" --inventory hosts.yml --ask-become-pass
    break
  done
)
