#!/usr/bin/env bash

set -e
set -o pipefail

declare EVAL PROVISIONED NIX_CONFIG NIX_USER_CONF_FILES

declare jq nix

jq="command jq --compact-output"
nix="command nix"

function eval_fn() {

  echo "::debug::Running $(basename "${BASH_SOURCE[0]}"):eval()"

  local nix_conf

  flake_url=${flake_url:="github:$OWNER_AND_REPO/$SHA"}

  nix_conf="$(mktemp -d)/nix.conf"
  export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true
access-tokens = ${ACCESS_TOKENS}
  "
  flake_path="$(nix flake metadata --json "$flake_url" | jq -r .path)/flake.nix"
  NIX_CONFIG+=$(nix eval --raw --impure --expr '(import '"$flake_path"').nixConfig or {}' --apply "$(<"${BASH_SOURCE[0]%/*}/nix_config.nix")")
  echo "$NIX_CONFIG" > "$nix_conf"
  NIX_USER_CONF_FILES="$nix_conf:${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf:$NIX_USER_CONF_FILES"
  export NIX_USER_CONF_FILES

  local system

  system="$(
    $nix eval --raw --impure --expr \
      'builtins.currentSystem'
  )"

  # will be a list of actions
  EVAL=$(
    $nix eval --show-trace --json \
      "$flake_url#__std.ci.$system"
  )

  if [ "$EVAL" = "[]" ]; then
    echo "Evaluation didn't find any targets..."
    echo "Please check that your Standard Registry isn't empty."
    echo "Open a Nix Repl and type:"
    echo "nix repl> :lf ."
    echo "nix repl> __std.\"ci\".$system"
    exit 1
  fi
}

function provision() {

  echo "::debug::Running $(basename "${BASH_SOURCE[0]}"):provision()"

  local by_action actions proviso provisioned
  PROVISIONED='[]'

  # group the list of actions by action and make that action the key
  by_action=$($jq --slurp '.[] | group_by(.action) | map({key: .[0].action, value: .}) | from_entries' <<<"${EVAL}")

  for action in $($jq --raw-output '.|keys[]' <<<"$by_action"); do
    actions=$($jq ".${action}" <<<"${by_action}")
    proviso=$($jq --raw-output ".${action}[0].proviso|strings" <<<"${by_action}")
    if [[ -n $proviso ]] && [[ $FILTER != false ]]; then
      echo "::debug::Running ${proviso##*/}"
      # this trick doesn't require proviso to be executable, as created by builtins.toFile
      function _proviso() { . "$proviso"; }
      provisioned="$(_proviso "$actions")"
      unset -f _proviso
      echo "::debug::Provisioned after proviso check: $provisioned"
    else
      echo "::debug::No proviso on action, passing all actions through."
      provisioned="$actions"
    fi
    PROVISIONED="$($jq '. + $new' --argjson new "$provisioned" <<<"$PROVISIONED")"
  done
}

function output() {

  echo "::debug::Running $(basename "${BASH_SOURCE[0]}"):output()"
  echo "::debug::See output json further down ..."

  local json delim

  json="$(
    $jq '
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
      | from_entries' <<<"$PROVISIONED"
  )"

  delim=$RANDOM

  printf "%s\n" \
    "json=$json" \
    "nix_conf<<$delim" \
    "${NIX_CONFIG[@]}" \
    "$delim" \
    >>"$GITHUB_OUTPUT"
}

echo "::group::🔎 Start Discovery ..."
eval_fn
provision
echo "::endgroup::"

echo "::group::✨ Find potential targets ..."
echo "${EVAL}" | jq -r '.[] | "//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::🌲️ Recycle previous work ..."
echo "... and only procede with these:"
echo "${PROVISIONED}" | jq -r '.[] | "//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::📞️ Inform the build matrix ..."
echo "... to tap the wire, enable debug logs :-)"
output
echo "::endgroup::"

unset jq nix
