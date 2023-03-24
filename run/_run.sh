#!/usr/bin/env bash

set -e
set -o pipefail
shopt -s lastpipe

function run() {

  echo "::debug::Running $(basename $BASH_SOURCE):run()"

  local action drv cell block target

  jq -r '.action + " " + .name + " " + .cell + " " + .block + " " + .actionDrv' <<<"$JSON" | read -r action target cell block drv

  echo "::group::🏍️️ $action //$cell/$block/$target"

  if [[ -z $BUILT ]]; then
    # should be fetched, since we have already checked cache status in build step
    nix-build "$drv" --no-out-link
  elif [[ $BUILDER != auto ]]; then
    nix copy --from "$BUILDER" "$drv"
  fi

  out="$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"
  if [[ ! -e $out ]]; then
    nix-build "$drv" --no-out-link
  fi

  # this trick preserves set -e & set -o pipefail from above
  function _run() { . "$out"; }
  _run
}

run
echo "::endgroup::"
