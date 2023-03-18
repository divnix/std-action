#!/usr/bin/env bash

set -e

target=$(jq -er '.actionDrv' <<<"$JSON")
declare -r target
declare -a uncached

#shellcheck disable=SC2068
function build() {

  echo "::debug::Running $(basename $BASH_SOURCE):build()"

  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2086
    nix-build --eval-store auto --store "$BUILDER" "$target"
  else
    echo "... already cached: there was no work to do."
  fi
}

echo "::group::📞️ Get info from discovery ..."
echo "... already here :-)"
echo "::endgroup::"

echo "::group::🏗️ Build target ..."
build
echo "::endgroup::"
