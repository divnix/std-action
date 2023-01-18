#!/usr/bin/env bash

set -e
shopt -s lastpipe

function check_exec() {
  path="$1"
  shift
  find -L "$path" -executable -type f "$@" 2>/dev/null
}

function run() {
  local action drv name

  jq -r '.action + " " + .name + " " + .actionDrv' <<< "$JSON" | read -r action name drv

  echo "::group::🏍️️ $action $name"

  if [[ -z $BUILT ]]; then
    # should be fetched, since we have already checked cache status in build step
    nix-build "$drv" --no-out-link
  elif [[ $BUILDER != auto ]]; then
    nix copy --from "$BUILDER" "$drv"
  fi

  out="$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"
  if [[ -a $out ]]; then
    "$out"
  else
    nix-build "$drv" --no-out-link
    "$out"
  fi
}

run
echo "::endgroup::"
