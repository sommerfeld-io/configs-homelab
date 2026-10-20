#!/usr/bin/env bash
# Molecule stub for nmap: prints canned scan output instead of scanning anything.
set -euo pipefail
samples=/usr/local/share/netaudit-samples
args="$*"
case "$args" in
--version*) echo "Nmap version 0.0 (netaudit molecule stub)" ;;
*"-p 22,80,443"*) cat "$samples/nmap-devices.txt" ;;
*"-sV -O"*) cat "$samples/nmap-services.txt" ;;
*http-title*) cat "$samples/nmap-web.txt" ;;
*ssl-cert*) cat "$samples/nmap-tls.txt" ;;
*broadcast-dhcp*) cat "$samples/nmap-broadcast.txt" ;;
*)
  echo "nmap stub: unexpected arguments: $args" >&2
  exit 1
  ;;
esac
