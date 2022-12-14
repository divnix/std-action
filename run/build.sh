#!/usr/bin/env bash

set -e

target=$(jq -er '.targetDrv' <<< "$JSON")
declare -r target
declare -a uncached

function calc_uncached() {
  echo "::group::Calculate Uncached Builds"

  set -x
  #shellcheck disable=SC2086
  mapfile -t uncached < <(nix-store --realise --dry-run $target 2>&1 1>/dev/null | sed '/paths will be fetched/,$ d' | grep '/nix/store/.*\.drv$')

  # filter out builds that are always run locally, and thus, not cached
  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2068
    mapfile -t uncached < <(nix show-derivation ${uncached[@]} | jq -r '.| to_entries[] | select(.value|.env.preferLocalBuild != "1") | .key')
  fi
  set +x


  echo "::debug::uncached paths: ${uncached[*]}"

  echo "uncached=${uncached[*]}" >> "$GITHUB_OUTPUT"

  echo "::endgroup::"
}


#shellcheck disable=SC2068
function build() {
  echo "::group::Nix Build"

  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2086
    nix-build --eval-store auto --store "$BUILDER" "$target"
  else
    echo "Everything already cached, nothing to build."
  fi

  echo "::endgroup::"
}

calc_uncached

build
