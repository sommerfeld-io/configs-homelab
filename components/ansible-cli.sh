#!/bin/bash
## TODO ... docs from docs/scripts/ansible-cli-sh.md
## TODO ... auto-generated Markdown file

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly ANSIBLE_USER="sebastian"


## Write a title to stdout.
##
## @arg $1 String The title to print
function title() {
  if [ -z "$1" ]; then
    echo -e "$LOG_ERROR No title passed"
    echo -e "$LOG_ERROR exit" && exit 8
  fi

  echo -e "$LOG_INFO ------------------------------------------"
  echo -e "$LOG_INFO     $1"
  echo -e "$LOG_INFO ------------------------------------------"
}


## Wrapper function to encapsulate ansible in a docker container using the
## link:https://hub.docker.com/r/cytopia/ansible[cytopia/ansible] image.
##
## Ansible runs in Docker as non-root user (the current user from the host is used inside the container).
## Filesystem dependencies are mounted into the container to ensure the user inside the container shares
## all relevant information with the user from the host.
##
## The current working directory is mounted into the container and selected as working directory so that
## all file of the project are available. Paths are preserved.
##
## @arg $@ String The ansible commands (1-n arguments) - $1 is mandatory
##
## @exitcode 8 If param with ansible command is missing
function invoke() {
  if [ -z "$1" ]; then
    echo -e "$LOG_ERROR No command passed to the ansible container"
    echo -e "$LOG_ERROR exit" && exit 8
  fi

  docker run -it --rm \
    --volume /etc/passwd:/etc/passwd:ro \
    --volume /etc/group:/etc/group:ro \
    --user "$(id -u):$(id -g)" \
    --volume "$HOME/.ansible:$HOME/.ansible:rw" \
    --volume "$HOME/.ssh:$HOME/.ssh:ro" \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    --volume "$(pwd):$(pwd)" \
    --workdir "$(pwd)" \
    --network host \
    cytopia/ansible:latest-tools "$@"
}


## Facade to map `ansible` command. The actual Ansible execution is delegated to
## Ansible running in a Docker container.
##
## @arg $@ String The ansible-playbook commands (1-n arguments) - $1 is mandatory
function ansible() {
  invoke ansible "$@"
}


## Facade to map `ansible-playbook` command. The actual Ansible execution is delegated to
## Ansible running in a Docker container.
##
## @arg $@ String The ansible-playbook commands (1-n arguments) - $1 is mandatory
function ansible-playbook() {
  invoke ansible-playbook "$@"
}


## Run Inspec test profiles in Docker containers to assert the installations
## and the state of the nodes on ly homelab.
# function run-tests() {
#   readonly TARGET_DIR="target"
#   readonly TEST_DIR="$TARGET_DIR/test/inspec"
#   readonly BASELINES=(
#     'ssl-baseline'
#   )
#
#   title 'Test'
#
#   echo -e "$LOG_INFO Validate inspec tests"
#   docker run --rm \
#     --volume ./src/test/inspec:/inspec \
#     --workdir /inspec \
#     chef/inspec:5.22.36 check homelab-baseline --chef-license=accept-no-persist
#
#   echo -e "$LOG_INFO Setup $TEST_DIR directory"
#   rm -rf "$TEST_DIR"
#   mkdir -p "$TEST_DIR"
#
#   echo -e "$LOG_INFO Download basline profiles from dev-sec.io"
#   for baseline in "${BASELINES[@]}"
#   do
#     echo -e "$LOG_INFO Download $P$baseline$D"
#     git clone "git@github.com:dev-sec/$baseline.git" "$TEST_DIR/$baseline"
#   done
#
#   echo -e "$LOG_INFO Run test-containers"
#   MY_USER="$USER" MY_UID="$(id -u)" MY_GID="$(id -g)" MY_SSH_AUTH_SOCK="$SSH_AUTH_SOCK" docker compose up
# }


title 'Ansible CLI'

(
  cd src/main/ansible || exit

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

# run-tests
