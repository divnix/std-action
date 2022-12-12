#!/usr/bin/env bash

set -e

declare JSON result

function eval() {
  echo "::group::Nix Evaluation"

  local system delim

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  result=$(nix eval "$FLAKE#__std.ci'.$system" --json)
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
      | from_entries' <<< "$result"
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

function cache() {
  echo "::group::Cache Evaluation"

  local drvs

  drvs=$(jq -r '.[]|select(.targetDrv != null)|.targetDrv' <<< "$result")

  if [[ -n $drvs ]]; then
    #shellcheck disable=SC2086
    nix copy --derivation --to "$CACHE" $drvs
  fi

  echo "::endgroup::"
}

eval

if [[ $CACHE != 'auto' ]]; then
  cache
fi
