#!/usr/bin/env bash

set -e
set -o pipefail

target=$(jq -er '.actionDrv' <<<"$JSON")
declare -r target
declare -a uncached

function calc_uncached() {

  echo "::debug::Running $(basename "${BASH_SOURCE[0]}"):calc_uncached()"

  #shellcheck disable=SC2086
  mapfile -t uncached < <(
    nix-store --realise --dry-run "$target" 2>&1 1>/dev/null |
      sed -nrf "$(dirname -- "${BASH_SOURCE[0]}")/build-uncached-extractor.sed"
  )

  # filter out builds that are always run locally, and thus, not cached
  if [[ -n ${uncached[*]} ]]; then
    #shellcheck disable=SC2068
    mapfile -t uncached < <(nix derivation show ${uncached[@]/%/^*} | jq -r '.| to_entries[] | select(.value|.env.preferLocalBuild != "1") | .key')
  fi

  echo "::debug::uncached paths: ${uncached[*]}"

  echo "${uncached[*]/%/^*}" >"$UNCACHED_FILE"

  if [[ -n ${uncached[*]} ]]; then
    echo "has_uncached=true" >>"$GITHUB_OUTPUT"
  fi
}

#shellcheck disable=SC2068
function build() {
  echo "::debug::Running $(basename "${BASH_SOURCE[0]}"):build()"

  #shellcheck disable=SC2086
  nix-build --eval-store auto --store "$BUILDER" "$target"
}

if [[ $CHECK != false ]]; then
  echo "::group::🧮 Collect what will be uploaded to the cache ..."
  calc_uncached
  echo "::endgroup::"
else
  echo "$target^*" > "$UNCACHED_FILE"
  echo "has_uncached=true" >>"$GITHUB_OUTPUT"
fi

if [[ -n ${uncached[*]} || $CHECK == false ]]; then
  echo "::group::🏗️ Build target ..."
  build
  echo "::endgroup::"
fi
