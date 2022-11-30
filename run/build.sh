#!/usr/bin/env bash

set -e

DRVS=$(jq -r '.|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$JSON")
declare -r DRVS

function calc_uncached() {
  echo "::group::Calculate Uncached Builds"

  #shellcheck disable=SC2086
  mapfile -s 1 -t unbuilt < <(nix-store --realise --dry-run $DRVS 2>&1 | sed '/paths will be fetched/,$ d')

  printf "%s\n" "::debug::uncached paths:" "${unbuilt[@]}"

  echo "uncached=${unbuilt[*]}" >> "$GITHUB_OUTPUT"

  echo "::endgroup::"
}


function build() {
  echo "::group::Nix Build"

  #shellcheck disable=SC2086
  printf "%s\n" "::debug::these paths will be built:" $DRVS

  #shellcheck disable=SC2086
  NIX_CONFIG=$(printf "%s\n" "eval-store = auto" "store = $BUILDER")  nix-store --realise $DRVS

  echo "::endgroup::"
}

calc_uncached

build
