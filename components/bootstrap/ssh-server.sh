#!/bin/bash
# @file ssh-server.sh
# @brief Install and configure openssh-server.
# @description
#   This script installs and configures openssh-server.
#
#   ```bash
#   curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/components/bootstrap/ssh-server.sh | bash -
#   ```
#
#   The script does not accept any parameters.


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
echo -e "$LOG_INFO |    Install and configure openssh-server           |"
echo -e "$LOG_INFO |    to allow further setup using Ansible.          |"
echo -e "$LOG_INFO +---------------------------------------------------+"
echo -e "$LOG_INFO Running on host ${P}$HOSTNAME${D}"


echo -e "$LOG_INFO ${Y}Update apt cache${D}"
sudo apt-get -y update

echo -e "$LOG_INFO ${Y}Install openssh-server${D}"
echo -e "$LOG_INFO Install and start SSH server"
sudo apt-get -y update
sudo apt-get install -y openssh-server
sudo ufw allow ssh # if the firewall is enabled on your system, open the ssh port
sudo systemctl enable --now ssh
