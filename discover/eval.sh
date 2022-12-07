#!/usr/bin/env bash

set -e

declare JSON

function eval() {
  echo "::group::Nix Evaluation"

  local system delim

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  JSON="$(nix eval "$FLAKE#__std.ci'.$system" --json | jq -c '
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
      | from_entries'
  )"

  nix_conf=("$(nix eval --raw "$FLAKE#__std.nixConfig")")

  delim=$RANDOM

  printf "%s\n" \
    "json=$JSON" \
    "nix_conf<<$delim" \
    "${nix_conf[@]}" \
    "$delim" \
    >> "$GITHUB_OUTPUT"

  echo "::debug::$JSON"

  echo "::endgroup::"
}

eval
