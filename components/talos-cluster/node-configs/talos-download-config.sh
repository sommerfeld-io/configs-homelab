#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

readonly REMOTE_USER="$USER"
readonly REMOTE_HOST="talos-admin-pi.fritz.box"
readonly REMOTE_PATH="work/repos/sommerfeld-io/configs-homelab/components/talos-cluster/node-configs"
readonly LOCAL_PATH="."

echo "[INFO] Download generated config files"
scp -r "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/generated" "$LOCAL_PATH"
