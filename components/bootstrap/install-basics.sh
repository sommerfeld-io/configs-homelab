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

echo -e "$LOG_INFO ${Y}Install Ansible${D}"
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y --update ppa:ansible/ansible
sudo apt-get install -y ansible

readonly TASK_VERSION="3.42.1"
readonly TASK_DEB="/tmp/task.deb"
echo -e "$LOG_INFO ${Y}Install Task v${TASK_VERSION}${D}"
curl -L -o "$TASK_DEB" "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_amd64.deb"
dpkg -i "$TASK_DEB"
rm "$TASK_DEB"
