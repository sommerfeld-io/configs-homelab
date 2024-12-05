#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


readonly OPTION_START="start"
readonly OPTION_STOP="stop"
readonly OPTION_RESTART="restart"
readonly OPTION_LOGS="logs"

STACK=""


# Utility function to startup docker compose services.
function startup() {
  echo -e "$LOG_INFO Startup stack $P$STACK$D on $P$HOSTNAME$D"
  docker compose up -d
}


# Utility function to shutdown docker compose services.
function shutdown() {
  echo -e "$LOG_INFO Shutdown stack $P$STACK$D on $P$HOSTNAME$D"
  docker compose down --rmi all --volumes --remove-orphans
}


# Utility function to show docker compose logs.
function logs() {
  echo -e "$LOG_INFO Show logs for stack $P$STACK$D on $P$HOSTNAME$D"
  docker compose logs -f
}

hostnamectl

(
  cd docker-stacks || exit

  echo -e "$LOG_INFO Select the docker compose stack"
  select s in */; do
    STACK="${s::-1}"
    break
  done

  (
    cd "$STACK" || exit

    echo -e "$LOG_INFO Select the action"
    select s in "$OPTION_START" "$OPTION_STOP" "$OPTION_RESTART" "$OPTION_LOGS"; do
      case "$s" in
        "$OPTION_START" )
          startup
          break;;
        "$OPTION_STOP" )
          shutdown
          break;;
        "$OPTION_RESTART" )
          shutdown
          startup
          break;;
        "$OPTION_LOGS" )
          logs
          break;;
      esac
    done
  )
)
