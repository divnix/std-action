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

  tmp="$(mktemp)"

  flake_file=${flake_file:="$tmp"}
  flake_url=${flake_url:="github:$OWNER_AND_REPO/$SHA"}

  if [ "$flake_file" = "$tmp" ]; then
    # only fetch if not (locally) defined (for testing)
    set -x
    gh api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "/repos/$OWNER_AND_REPO/contents/flake.nix?ref=$SHA" |
      $jq -r '.content|gsub("[\n\t]"; "")|@base64d' >"$flake_file"
    set +x
  fi

  nix_conf="$(mktemp -d)/nix.conf"
  NIX_CONFIG=$(nix eval --raw --impure --expr '(import '"$flake_file"').nixConfig or {}' --apply "$(<"${BASH_SOURCE[0]%/*}/nix_config.nix")" | tee "$nix_conf")
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
    readarray -t actions < <($jq --raw-output ".${action}[] | @base64" <<<"${by_action}")
    echo "Check proviso for all ${#actions[@]} '$action' action(s) ..."
    # this trick doesn't require proviso to be executable, as created by builtins.toFile
    function _proviso() {
        _jq() { echo "${2}" | command base64 --decode | command jq --compact-output --raw-output "${1}"; }
        local action="$1"
        >&2 echo -n "... checking $(_jq '"//\(.cell)/\(.block)/\(.name):\(.action)"' $action)"
        local proviso=$(_jq '.proviso|strings' $action)
        if [[ -n $proviso ]]; then
          cmd=(bash -o errexit -o nounset -o pipefail "$proviso" "$(_jq '.' $action)")
          if ${cmd[@]}; then
            >&2 echo " - take it."
            echo "$action"
          else
            >&2 echo " - drop it."
          fi
        else
          >&2 echo " - take it (no proviso)."
          echo "$action"
        fi
    }
    export -f _proviso
    readarray -t args < <(
      parallel -j0 _proviso ::: "${actions[@]}"
      # for a in ${actions[@]}; do _proviso "$a"; done
    )
    echo "Continue with ${#args[@]} '$action' action(s)."
    if [[ ${#args[@]} -ne 0 ]]; then
      PROVISIONED="$(
        $jq '. + ($ARGS.positional | map(@base64d|fromjson))' \
        --args "${args[@]}" \
        <<<"$PROVISIONED"
      )"
    fi
    unset -f _proviso
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

  base64 <<<"$json" | tr -d '\n'
  echo
  echo "(base64)"

  delim=$RANDOM

  printf "%s\n" \
    "json=$json" \
    "nix_conf<<$delim" \
    "${NIX_CONFIG[@]}" \
    "$delim" \
    >>"$GITHUB_OUTPUT"
}

echo "::group::📓 Evaluate ..."
eval_fn
echo "::endgroup::"

echo "::group::✨ Find potential targets ..."
echo "${EVAL}" | jq -r '.[] | "//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::🔎 Check for proviso ..."
provision
echo "::endgroup::"

echo "::group::🌲️ Save work and only proceed with  ..."
echo "${PROVISIONED}" | jq -r '.[] | "//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::📞️ Inform the build matrix ..."
output
echo "::endgroup::"

unset jq nix
