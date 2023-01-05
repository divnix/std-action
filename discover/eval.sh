#!/usr/bin/env bash

set -e

declare -a LIST
declare PROVISIONED NIX_CONFIG

function eval() {
  echo "::group::Nix Evaluation"

  local system

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  mapfile -t LIST < <(nix eval "$FLAKE#__std.ci'.$system" --show-trace --json | jq -c 'unique_by(.actionDrv)|.[]')

  if [[ -z ${LIST[*]} ]]; then
    exit 1
  fi

  echo "::endgroup::"
}

function provision() {
  echo "::group::Provison Jobs"

  local by_action proviso
  local -a action_list

  by_action=$(jq -sc 'group_by(.action)|map({key: .[0].action, value: .})| from_entries' <<< "${LIST[@]}")

  PROVISIONED='[]'

  NIX_CONFIG=("$(nix eval --raw "$FLAKE#__std.nixConfig")")
  export NIX_CONFIG

  for type in $(jq -r 'to_entries[].key' <<< "$by_action"); do
    mapfile -t action_list < <(jq -c ".${type}[]" <<< "$by_action")
    proviso=$(jq -sr '.[0].proviso' <<< "${action_list[@]}")
    if [[ $proviso != 'null' ]]; then
      # shellcheck disable=SC1090
      . "$proviso"
      proviso action_list PROVISIONED
    else
      PROVISIONED=$(jq -cs '. += $p' --argjson p "$PROVISIONED" <<< "${action_list[@]}")
    fi
  done

  echo "::endgroup::"
}

function output() {
  echo "::group::Set Outputs"

  local json delim

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

  delim=$RANDOM

  printf "%s\n" \
    "json=$json" \
    "nix_conf<<$delim" \
    "${NIX_CONFIG[@]}" \
    "$delim" \
    >> "$GITHUB_OUTPUT"

  echo "::debug::$json"

  echo "::endgroup::"
}


eval

provision

output