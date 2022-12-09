#!/usr/bin/env bash

set -e
shopt -s lastpipe

function check_exec() {
  path="$1"
  shift
  find -L "$path" -executable -type f "$@" 2>/dev/null
}

function run() {
  local action drv

  jq -r '.action + " " + .name + " " + .targetDrv' <<< "$JSON" | read -r action name drv

  echo "::group::$action $name"

  if [[ -z $BUILT ]]; then
    # should be fetched, since we have already checked cache status in build step
    nix-build "$drv" --no-out-link
  elif [[ $BUILDER != auto ]]; then
    nix copy --from "$BUILDER" "$drv"
  fi

  out="$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"
  # if the outpath is a script execute it
  if [[ -n $(check_exec "$out" -maxdepth 0) ]]; then
    "$out"
  # else check for a script with the same name
  elif [[ -n $(check_exec "$out/bin/$name") ]]; then
    "$out/bin/$name"
  else
    # find first executable file in $out/bin
    executable=$(check_exec "$out/bin" | head -1)
    if [[ -n $executable ]]; then
      "$executable"
    else
      echo "Target is not executable, nothing to run."
    fi
  fi

  echo "::endgroup::"
}

run
