#!/usr/bin/env bash

set -e

declare JSON

function eval() {
  echo "::group::Nix Evaluation"

  local system

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

  echo "json=$JSON" >> "$GITHUB_OUTPUT"

  echo "nix_conf=$(nix eval --raw "$FLAKE#__std.nixConfig")" >> "$GITHUB_OUTPUT"

  echo "::debug::$JSON"

  echo "::endgroup::"
}

eval
