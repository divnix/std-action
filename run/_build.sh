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

echo "::group::📞️ Get info from discovery ..."
echo "... already here :-)"
echo "::endgroup::"

echo "::group::🧮 Collect what will be uploaded to the cache ..."
if [[ $CHECK != false ]]; then
  calc_uncached
else
  echo "$target^*" > "$UNCACHED_FILE"
  echo "has_uncached=true" >>"$GITHUB_OUTPUT"
fi
echo "::endgroup::"

if [[ -n ${uncached[*]} ]]; then
  echo "::group::🏗️ Build target ..."
  build
  echo "::endgroup::"
fi
