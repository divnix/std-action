#!/usr/bin/env bash

set -e

declare -a LIST
declare PROVISIONED NIX_CONFIG

function eval() {

  echo "::debug::Running $(basename $BASH_SOURCE):eval()"

  local system

  system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
  mapfile -t LIST < <(nix eval "$FLAKE#__std.ci'.$system" --show-trace --json | jq -c 'unique_by(.actionDrv)|.[]')

  if [[ -z ${LIST[*]} ]]; then
    echo "Evaluation didn't find any targets..."
    echo "Please check that your Standard Registry isn't empty."
    echo "Open a Nix Repl and type:"
    echo "nix repl> :lf."
    echo "nix repl> __std.\"ci'\".$system"
    exit 1
  fi
}

function provision() {

  echo "::debug::Running $(basename $BASH_SOURCE):provision()"

  local by_action proviso
  local -a action_list
  local nix_conf

  by_action=$(jq -sc 'group_by(.action)|map({key: .[0].action, value: .})| from_entries' <<< "${LIST[@]}")

  PROVISIONED='[]'

  nix_conf="$(mktemp -d)/nix.conf"
  NIX_CONFIG=$(nix eval --raw "$FLAKE#__std.nixConfig" | tee "$nix_conf")
  NIX_USER_CONF_FILES="$nix_conf:${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf:$NIX_USER_CONF_FILES"
  export NIX_USER_CONF_FILES

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
}

function output() {

  echo "::debug::Running $(basename $BASH_SOURCE):output()"

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
}


echo "::group::🔎 Start Discovery ..."
eval
provision
echo "::endgroup::"

echo "::group::✨ Find potential targets ..."
echo "${LIST[@]}" | jq -r '"//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::🌲️ Recycle previous work ..."
echo "... and only procede with these:"
echo "${PROVISIONED[@]}" | jq '.[]' | jq -r '"//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::📞️ Inform the build matrix ..."
echo "... to tap the wire, enable debug logs :-)"
output
echo "::endgroup::"
