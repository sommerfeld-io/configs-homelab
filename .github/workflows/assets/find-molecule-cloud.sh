#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

## Print every cloud Molecule scenario folder of the repository, one per line, sorted.
##
## A scenario folder is a folder below `configs-cloud/` with a tracked `molecule/default/molecule.yml`
## (the folder `molecule test` runs in). Roles in submodules are not tracked here, so their
## scenarios are not listed. The `molecule-cloud` job in `pipeline.yml` and `task cloud:molecule:test` both read this
## list, so a new scenario is tested without editing either. Exits 1 when no scenario is found.
function main() {
  local scenarios
  # Paths are relative to the repository root, wherever the script is called from.
  scenarios="$(cd "$(git rev-parse --show-toplevel)" && git ls-files -- ':(glob)configs-cloud/**/molecule/default/molecule.yml' | sed 's|/molecule/default/molecule.yml$||' | LC_ALL=C sort -u)"
  if [ -z "$scenarios" ]; then
    echo "no cloud Molecule scenario (folder with a tracked molecule/default/molecule.yml below configs-cloud/) found" >&2
    exit 1
  fi
  echo "$scenarios"
}

main
