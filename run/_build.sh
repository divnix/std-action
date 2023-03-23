#!/usr/bin/env bash

set -e

target=$(jq -er '.actionDrv' <<<"$JSON")
declare -r target
declare -a uncached

function calc_uncached() {

  echo "::debug::Running $(basename $BASH_SOURCE):calc_uncached()"

  #shellcheck disable=SC2086
  mapfile -t uncached < <(nix-store --realise --dry-run $target 2>&1 1>/dev/null | sed '/paths will be fetched/,$ d' | grep '/nix/store/.*\.drv$')

  # filter out builds that are always run locally, and thus, not cached
  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2068
    mapfile -t uncached < <(nix show-derivation ${uncached[@]} | jq -r '.| to_entries[] | select(.value|.env.preferLocalBuild != "1") | .key')
  fi

  echo "::debug::uncached paths: ${uncached[*]}"

  echo "uncached=${uncached[*]}" >>"$GITHUB_OUTPUT"
}

#shellcheck disable=SC2068
function build() {

  echo "::debug::Running $(basename $BASH_SOURCE):build()"

  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2086
    nix-build --eval-store auto --store "$BUILDER" "$target"
  fi
}

echo "::group::📞️ Get info from discovery ..."
echo "... already here :-)"
echo "::endgroup::"

echo "::group::🧮 Collect what will be uploaded to the cache ..."
calc_uncached
echo "::endgroup::"

echo "::group::🏗️ Build target ..."
build
echo "::endgroup::"
