#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace


echo -e "$LOG_INFO ========== System Info =================================================="
echo "        Hostname: $HOSTNAME"
hostnamectl
echo "          Kernel: $(uname -v)"
echo -e "$LOG_INFO ========================================================================="
