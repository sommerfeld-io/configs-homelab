#!/bin/bash

readonly IMAGE="chef/inspec:5.22.76"
readonly PROFILE="ansible-baseline"

set -o errexit
set -o pipefail
# set -o nounset
# set -o xtrace

if [ -z "$1" ]; then
  echo "[ERROR] No ssh connection provided"
  echo "[ERROR]   use e.g. sebastian@caprica.fritz.box"
  echo "[ERROR] Exited with code 1"
  exit 1
fi

echo "[INFO] Inspec version: $IMAGE"
echo "[INFO] Profile: $PROFILE"
echo "[INFO] System under test: $1"

echo "[INFO] ======================================="
echo "[INFO] Validate inspec profile"
echo "[INFO] ======================================="

docker run --rm \
  --volume "$(pwd):$(pwd)" \
  --workdir "$(pwd)" \
  "$IMAGE" check "$PROFILE" --chef-license=accept

echo "[INFO] ======================================="
echo "[INFO] Running inspec tests"
echo "[INFO] ======================================="

docker run --rm \
  --env SSH_AUTH_SOCK=/ssh-auth.sock \
  --volume "$SSH_AUTH_SOCK:/ssh-auth.sock" \
  --volume "$(pwd):$(pwd)" \
  --workdir "$(pwd)" \
  "$IMAGE" exec "$PROFILE" --target "ssh://$1" --chef-license=accept
