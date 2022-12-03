#!/usr/bin/env bash

set -e

declare JSON

function eval() {
  echo "::group::Nix Evaluation"

  local system

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  list="$(nix eval "$FLAKE#__std.ci'.$system" --json)"
  JSON="$(jq -c '
      group_by(.block)
      | map({
        key: .[0].block,
        value: (
          group_by(.action)
          | map({
            key: .[0].action,
            value: .
          })
          | from_entries
        )
      })
      | from_entries' <<< "$list"
  )"

  echo "json=$JSON" >> "$GITHUB_OUTPUT"

  echo "nix_conf=$(nix eval --raw "$FLAKE#__std.nixConfig")" >> "$GITHUB_OUTPUT"

  echo "::debug::$JSON"

  echo "::endgroup::"
}

function archive() {
  echo "::group::Archive Evaluation Result"

  #shellcheck disable=SC2046
  nix copy \
    --no-check-sigs \
    --derivation \
    --no-auto-optimise-store \
    --to "$DISC_PATH" \
    $(jq -r '.[]|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$list")

  tar -C "$DISC_PATH" --zstd -f "$DISC_ARC_PATH" -c .

  echo "::endgroup::"
}

eval

archive
