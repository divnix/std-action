#!/usr/bin/env bash

set -e

function upload() {
  echo "::group::Upload to Cache"

  echo "::debug::uploading$UNCACHED"

  if [[ -n "$NIX_KEY_PATH" && $CACHE =~ ^s3:// ]]; then
    if [[ $CACHE =~ \? ]]; then
      CACHE="$CACHE&secret-key=$NIX_KEY_PATH"
    else
      CACHE="$CACHE?secret-key=$NIX_KEY_PATH"
    fi
  fi

  echo "$UNCACHED" | xargs -- nix copy --from "$BUILDER" --to "$CACHE"

  echo "::endgroup::"
}

upload
