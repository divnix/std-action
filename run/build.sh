#!/usr/bin/env bash

set -e

DRVS=$(jq -r '.|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$JSON")
declare -r DRVS
declare -a uncached

function calc_uncached() {
  echo "::group::Calculate Uncached Builds"

  #shellcheck disable=SC2086
  mapfile -t uncached < <(nix-store --realise --dry-run $DRVS 2>&1 1>/dev/null | sed '/paths will be fetched/,$ d' | grep '/nix/store/.*\.drv$')

  echo "::debug::uncached paths: ${uncached[*]}"

  echo "uncached=${uncached[*]}" >> "$GITHUB_OUTPUT"

  echo "::endgroup::"
}


#shellcheck disable=SC2068
function build() {
  echo "::group::Nix Build"

  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2086
    echo "::debug::these paths will be built: $DRVS"

    echo "${uncached[@]}" | xargs -- nix-build --eval-store auto --store "$BUILDER"
  else
    echo "Everything already cached, nothing to build."
  fi

  echo "::endgroup::"
}

calc_uncached

build
