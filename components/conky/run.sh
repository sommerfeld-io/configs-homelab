#!/bin/bash
# @file run.sh
# @brief Start all Conky instances.
# @description
#   The script starts all Conky instances. By default this script is triggered
#   automatically when the machine starts (the script is configured as a startup application
#   by ansible playbook).
#
#   ### Script Arguments
#   The script does not accept any parameters.


readonly BASE_PATH="$HOME/work/repos/sommerfeld-io/configs-homelab/components/conky"
readonly CONKYRC_PATH="$BASE_PATH/conkyrc-$HOSTNAME"
readonly DELAY="2m"
#readonly DELAY="5s"

echo -e "$LOG_INFO Copy launcher to autostart"
cp "assets/conky-launcher.desktop" "$HOME/.config/autostart/conky-launcher.desktop"

echo -e "$LOG_INFO Start all conky instances in background (sleep $DELAY first)"
sleep "$DELAY"

for rc in "$CONKYRC_PATH"/*.conkyrc; do
  echo -e "$LOG_INFO Start Instance ${P}${rc}${D}"
  sleep 10s
  conky -c "$rc" &
done
