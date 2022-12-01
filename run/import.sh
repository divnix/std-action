#!/usr/bin/env bash

set -e

function import() {
  echo "::group::Import Discovery"

  mkdir -p "$DISC_PATH"

  sudo tar -C / --zstd -f "$DISC_ARC_PATH" -x .
  sudo chown root:root /

  echo "::endgroup::"
}

import