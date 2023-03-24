#!/usr/bin/env bash

set -e
set -o pipefail

function upload() {

  echo "::debug::Running $(basename $BASH_SOURCE):upload()"

  echo "::debug::uploading$UNCACHED"

  if [[ -n $NIX_KEY_PATH && $CACHE =~ ^s3:// ]]; then
    if [[ $CACHE =~ \? ]]; then
      CACHE="$CACHE&secret-key=$NIX_KEY_PATH"
    else
      CACHE="$CACHE?secret-key=$NIX_KEY_PATH"
    fi
  fi

  echo "$UNCACHED" | xargs -- nix copy --from "$BUILDER" --to "$CACHE"
}

echo "::group::🌲 Recycle work into cache ..."
upload
echo "::endgroup::"
