#!/bin/bash

TARGET_PATH="work/repos/sommerfeld-io/configs-homelab/components"

echo "[INFO] Run docker-stacks-cli.sh -----------------"
(
  echo "Change into $TARGET_PATH"

  cd "$TARGET_PATH" || exit
  ./docker-stacks-cli.sh
)
