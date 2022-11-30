#!/usr/bin/env bash

set -e

declare JSON

function eval() {
  echo "::group::Nix Evaluation"

  local system

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  JSON="$(nix eval "$FLAKE#__std.ci.$system" --json)"

  echo "json=$JSON" >> "$GITHUB_OUTPUT"

  echo "nix_conf=$(nix eval --raw "$FLAKE#__std.nixConfig")" >> "$GITHUB_OUTPUT"

  echo "::debug::$JSON"

  echo "::endgroup::"
}

function archive() {
  echo "::group::Archive Eval Store"

  #shellcheck disable=SC2046
  nix copy \
    --no-check-sigs \
    --derivation \
    --no-auto-optimise-store \
    --to "$DISC_PATH" \
    $(jq -r '.[]|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$JSON")

  tar -C "$DISC_PATH" --zstd -f "$DISC_ARC_PATH" -c .

  echo "::endgroup::"
}

eval

archive