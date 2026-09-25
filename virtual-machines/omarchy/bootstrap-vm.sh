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

echo -e "$LOG_INFO +-------------------------------------+"
echo -e "$LOG_INFO |    Initialize Ansible on Omarchy    |"
echo -e "$LOG_INFO +-------------------------------------+"
echo -e "$LOG_INFO Running on host ${P}$HOSTNAME${D}"

echo -e "$LOG_INFO ${Y}Install Python (required by Ansible)${D}"
omarchy pkg add ansible

echo -e "$LOG_INFO ${Y}Install task${D}"
pacman -S go-task
sudo ln -s /usr/bin/go-task /usr/local/bin/task
