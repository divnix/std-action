#!/usr/bin/env bash

set -e
set -o pipefail
shopt -s lastpipe

function run() {

  echo "::debug::Running $(basename $BASH_SOURCE):run()"

  local action drv name

  jq -r '.action + " " + .name + " " + .actionDrv' <<<"$JSON" | read -r action name drv

  echo "::group::🏍️️ $action $name"

  if [[ -z $BUILT ]]; then
    # should be fetched, since we have already checked cache status in build step
    nix-build "$drv" --no-out-link
  elif [[ $BUILDER != auto ]]; then
    nix copy --from "$BUILDER" "$drv"
  fi

  out="$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"
  if [[ -e $out ]]; then
    "$out"
  else
    nix-build "$drv" --no-out-link
    "$out"
  fi
}

run
echo "::endgroup::"
