#!/bin/bash
# @file install-basics.sh
# @brief Install basic tools and apply basic configs to allow further setup using Ansible.
# @description
#   This script runs the basic provisioning. This is a prerequisite to run the ansible steps.
#
#   ```bash
#   curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/components/bootstrap/basics.sh | bash -
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
echo -e "$LOG_INFO |    Install basic tools and apply basic configs    |"
echo -e "$LOG_INFO |    to allow further setup using Ansible.          |"
echo -e "$LOG_INFO +---------------------------------------------------+"
echo -e "$LOG_INFO Running on host ${P}$HOSTNAME${D}"


echo -e "$LOG_INFO ${Y}Update apt cache${D}"
sudo apt-get -y update

echo -e "$LOG_INFO ${Y}Install basics${D}"
sudo apt-get install -y ca-certificates
sudo apt-get install -y curl
sudo apt-get install -y gnupg
sudo apt-get install -y lsb-release

echo -e "$LOG_INFO ${Y}Install git${D}"
sudo apt-get install -y git

echo "[INFO] Install Ansible"
readonly UBUNTU_CODENAME=oracular
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | sudo gpg --dearmour -o /usr/share/keyrings/ansible-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/ansible.list
sudo apt-get update
sudo apt-get install -y ansible
