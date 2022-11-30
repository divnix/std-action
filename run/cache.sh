#!/usr/bin/env bash

set -e

function upload() {
  echo "::group::Upload to Cache"

  printf "%s\n" "::debug::uploading:" "$UNCACHED"

  if [[ $CACHE =~ ^s3:// ]]; then
    if [[ $CACHE =~ ? ]]; then
      CACHE="$CACHE&secret-key=$NIX_KEY_PATH"
    else
      CACHE="$CACHE?secret-key=$NIX_KEY_PATH"
    fi
  fi

  #shellcheck disable=SC2086
  nix copy --from "$BUILDER" --to "$CACHE" $UNCACHED

  echo "::endgroup::"
}

upload
