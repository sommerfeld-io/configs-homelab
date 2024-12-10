#!/bin/bash

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


# Write a title to stdout.
#
# @arg $1 String The title to print
function title() {
  if [ -z "$1" ]; then
    echo -e "$LOG_ERROR No title passed"
    exit 8
  fi

  echo -e "$LOG_INFO ------------------------------------------"
  echo -e "$LOG_INFO     $1"
  echo -e "$LOG_INFO ------------------------------------------"
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
