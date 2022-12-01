#!/usr/bin/env bash

set -e
shopt -s lastpipe

function run() {
  local action drv

  jq -r '.action + " " + .actionDrv' <<< "$JSON" | read -r action drv

  echo "::group::Running $action"

  if [[ $BUILDER != auto ]]; then
    nix copy --no-check-sigs --from "$BUILDER" --to auto "$drv"
  fi

  # run the action script
  eval "$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"

  echo "::endgroup::"
}

run
