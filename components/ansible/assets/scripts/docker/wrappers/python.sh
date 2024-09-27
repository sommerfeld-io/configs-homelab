#!/bin/bash
## TODO
## The script is a wrapper to use Python from a Docker container when using the `py`
## command. The script delegates the all tasks to the Python runtime inside a container using image
## link:https://hub.docker.com/_/python[python].
##
## CAUTION: Since Ubuntu comes with a pre-installed python, the `python`, `python3` and `python3.9`
## commands are already allocated. To make sure only custom developments use this script, the `py`
## command is introduced.
##
## In order to use the `py` command (not `python`) the symlink `/usr/bin/py` is added.
##
## CAUTION: To update scripts, adjust files at `~/work/repos/sommerfeld-io/configs-homelab/components/ansible/assets/scripts/docker/wrappers` and run ansible playbook.
##
## === Script Arguments
## * *$@* (array): Original arguments


set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly IMAGE="python"
readonly TAG="3.9.10"

docker run -it --rm \
  --volume "$(pwd):$(pwd)" \
  --workdir "$(pwd)" \
  "$IMAGE:$TAG" python "$@"
