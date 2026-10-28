#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

## Print every InSpec profile of the repository, one per line, sorted.
##
## A profile is a folder with a tracked `inspec.yml`. Vendored dependency profiles are not
## tracked (each profile's `.gitignore` excludes `vendor/`), so they are not listed. The
## `check-inspec-profile` job in `pipeline.yml` and `task homelab:inspec:check` both read this
## list, so a new profile is checked without editing either. Exits 1 when no profile is found.
function main() {
  local profiles
  # Paths are relative to the repository root, wherever the script is called from.
  profiles="$(cd "$(git rev-parse --show-toplevel)" && git ls-files -- ':(glob)**/inspec.yml' | xargs --no-run-if-empty -n1 dirname | LC_ALL=C sort -u)"
  if [ -z "$profiles" ]; then
    echo "no InSpec profile (folder with a tracked inspec.yml) found" >&2
    exit 1
  fi
  echo "$profiles"
}

main
