#!/usr/bin/env bash

set -e

declare -a LIST
declare PROVISIONED

function eval() {
  echo "::group::Nix Evaluation"

  local system

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  mapfile -t LIST < <(nix eval "$FLAKE#__std.ci'.$system" --json | jq -c 'unique_by(.actionDrv)|.[]')

  echo "::endgroup::"
}

function provision() {
  echo "::group::Provison Jobs"

  PROVISIONED='[]'

  for action in "${LIST[@]}"; do
    proviso="$(jq -r '.proviso' <<< "$action")"
    if [[ $proviso == null ]] || (builtin eval "$proviso"); then
      if [[ $proviso != null ]]; then
        action=$(jq -c 'del(.proviso)' <<< "$action")
      fi
      PROVISIONED=$(jq ". += [$action]" <<< "$PROVISIONED")
    fi
  done

  echo "::endgroup::"
}

function output() {
  echo "::group::Set Outputs"

  local json delim nix_conf

  json="$(jq -c '
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
      | from_entries' <<< "$PROVISIONED"
  )"

  nix_conf=("$(nix eval --raw "$FLAKE#__std.nixConfig")")

  delim=$RANDOM

  printf "%s\n" \
    "json=$json" \
    "nix_conf<<$delim" \
    "${nix_conf[@]}" \
    "$delim" \
    >> "$GITHUB_OUTPUT"

  echo "::debug::$json"

  echo "::endgroup::"
}


eval

provision

output