#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

## Use nftables backend for iptables to ensure Docker networking works on Ubuntu 26.04+
## TODO ... check if this is needed after a docker or devcontainer or dind feature update
sudo update-alternatives --set iptables /usr/sbin/iptables-nft
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
