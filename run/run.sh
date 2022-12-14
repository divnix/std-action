#!/usr/bin/env bash

set -e
shopt -s lastpipe

function check_exec() {
  path="$1"
  shift
  find -L "$path" -executable -type f "$@" 2>/dev/null
}

function run() {
  local action drv name target

  jq -r '.action + " " + .name + " " + .actionDrv + " " + .targetDrv' <<< "$JSON" | read -r action name drv target

  echo "::group::$action $name"

  if [[ -z $BUILT ]]; then
    # should be fetched, since we have already checked cache status in build step
    nix-build "$target" "$drv" --no-out-link
  elif [[ $BUILDER != auto ]]; then
    nix copy --from "$BUILDER" "$target"
  fi

  out="$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"
  if [[ -a $out ]]; then
    "$out"
  else
    nix-build "$drv" --no-out-link
    "$out"
  fi

  echo "::endgroup::"
}

run
