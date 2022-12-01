#!/usr/bin/env bash

set -e

DRVS=$(jq -r '.|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$JSON")
declare -r DRVS

function calc_uncached() {
  echo "::group::Calculate Uncached Builds"

  #shellcheck disable=SC2086
  mapfile -s 1 -t unbuilt < <(nix-store --realise --dry-run $DRVS 2>&1 | sed '/paths will be fetched/,$ d')

  echo "::debug::uncached paths: ${unbuilt[*]}"

  echo "uncached=${unbuilt[*]}" >> "$GITHUB_OUTPUT"

  echo "::endgroup::"
}


#shellcheck disable=SC2068
function build() {
  echo "::group::Nix Build"

  #shellcheck disable=SC2086
  echo "::debug::these paths will be built: $DRVS"

  nix-build --eval-store auto --store "$BUILDER" ${unbuilt[@]}

  echo "::endgroup::"
}

calc_uncached

build
