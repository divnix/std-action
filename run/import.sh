#!/usr/bin/env bash

set -e

declare -r DISC="$TMPDIR/discovery"

function import() {
  echo "::group::Import Discovery"

  if [[ $NIX_KEY_PATH != "" ]]; then
    nix store sign -r -k "$NIX_KEY_PATH" --all --store "$DISC"
  fi

  nix copy --all --from "$DISC" --to auto

  echo "::endgroup::"
}

import