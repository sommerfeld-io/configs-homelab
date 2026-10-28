#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

## Print every OpenTofu root module of the repository, one per line, sorted.
##
## A root module is a folder with a tracked `versions.tf`, except folders below a `modules/`
## folder (child modules usually pin a version range, which the CI image tag cannot use). The `validate-opentofu` job in
## `pipeline.yml` and `task opentofu:validate` both read this list, so a new root is validated
## without editing either. Exits 1 when no root is found.
function main() {
  local roots
  # Paths are relative to the repository root, wherever the script is called from.
  roots="$(cd "$(git rev-parse --show-toplevel)" && git ls-files -- ':(glob)**/versions.tf' ':(glob,exclude)**/modules/**' | xargs --no-run-if-empty -n1 dirname | LC_ALL=C sort -u)"
  if [ -z "$roots" ]; then
    echo "no OpenTofu root module (folder with a tracked versions.tf) found" >&2
    exit 1
  fi
  echo "$roots"
}

main
