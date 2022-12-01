#!/usr/bin/env bash

set -e

function import() {
  echo "::group::Import Discovery"

  mkdir -p "$DISC_PATH"

  tar -C "$DISC_PATH" --zstd -f "$DISC_ARC_PATH" -x .

  if [[ $NIX_KEY_PATH != "" ]]; then
    nix store sign -r -k "$NIX_KEY_PATH" --all --store "$DISC_PATH"
  fi

  nix copy --all --from "$DISC_PATH" --to auto

  echo "::endgroup::"
}

import