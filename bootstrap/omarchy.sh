#!/bin/bash
# Initialize SSH and other mandatory things to allow further setup using Ansible.
# Password-less SSH auth (ssh-copy-id) stays a manual step and is not handled here.
# Run with: curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/omarchy.sh | bash -

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

# readonly LOG_DONE="[\e[32mDONE\e[0m]"
# readonly LOG_ERROR="[\e[1;31mERROR\e[0m]"
readonly LOG_INFO="[\e[34mINFO\e[0m]"
# readonly LOG_WARN="[\e[93mWARN\e[0m]"
readonly Y="\e[93m"
readonly P="\e[35m"
readonly D="\e[0m"

echo -e "$LOG_INFO +---------------------------------------------------+"
echo -e "$LOG_INFO |    Initialize Omarchy for Ansible provisioning    |"
echo -e "$LOG_INFO +---------------------------------------------------+"
echo -e "$LOG_INFO Running on host ${P}$HOSTNAME${D}"

echo -e "$LOG_INFO ${Y}Install Python (required by Ansible)${D}"
omarchy pkg add python

echo -e "$LOG_INFO ${Y}Install and start openssh${D}"
omarchy pkg add openssh
sudo systemctl enable --now sshd

echo -e "$LOG_INFO ${Y}Allow SSH through the firewall${D}"
sudo ufw allow ssh # ufw is active by default on Omarchy and silently drops SSH otherwise
sudo ufw reload

echo -e "$LOG_INFO ${Y}Confirm sshd is listening${D}"
sudo ss -tlnp | grep ':22 ' || true

echo -e "$LOG_INFO Done. Password-less SSH auth (ssh-copy-id) is still a manual step."
