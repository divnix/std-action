#!/usr/bin/env bash

set -e
set -o pipefail

declare EVAL PROVISIONED NIX_CONFIG

flake_url=${flake_url:="github:$OWNER_AND_REPO/$SHA"}

function eval_fn() {
  echo "::debug::Running $(basename "${BASH_SOURCE[0]}"):eval()"

  local system

  system="$(
    command nix eval --raw --impure --expr \
      'builtins.currentSystem'
  )"

  # will be a list of actions
  EVAL=$(
    command nix eval --show-trace --json \
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

  PROVISIONED='[]'

  # group the list of actions by action and make that action the key
  by_action=$(command jq --compact-output --slurp '.[] | group_by(.action) | map({key: .[0].action, value: .}) | from_entries' <<<"${EVAL}")

  for action in $(command jq --compact-output --raw-output '.|keys[]' <<<"$by_action"); do
    readarray -t actions < <(command jq --compact-output --raw-output ".${action}[] | @base64" <<<"${by_action}")
    echo "Check proviso for ${#actions[@]} '$action' action(s) ..."
    # this trick doesn't require proviso to be executable, as created by builtins.toFile
    function _proviso() {
      _jq() { echo "${2}" | command base64 --decode | command jq --compact-output --raw-output "${1}"; }
      local action="$1"
      echo >&2 -n "... checking $(_jq '"//\(.cell)/\(.block)/\(.name):\(.action)"' "$action")"
      local proviso
      proviso=$(_jq '.proviso|strings' "$action")
      if [[ -n $proviso ]]; then
        cmd=(command bash -o errexit -o nounset -o pipefail "$proviso" "$(_jq '.' "$action")")
        if "${cmd[@]}"; then
          echo >&2 " - take it."
          echo "$action"
        else
          echo >&2 " - drop it."
        fi
      else
        echo >&2 " - take it (no proviso)."
        echo "$action"
      fi
    }
    export -f _proviso
    readarray -t args < <(
      if ! command -v parallel &>/dev/null; then
        for a in "${actions[@]}"; do _proviso "$a"; done
      else
        command parallel -j0 _proviso ::: "${actions[@]}"
      fi
    )
    echo "Continue with ${#args[@]} '$action' action(s)."
    if [[ ${#args[@]} -ne 0 ]]; then
      jqprg='. + ($ARGS.positional | map(@base64d|fromjson|
        (. * {"jobName": "\(.action) //\(.cell)/\(.block)/\(.name)"})
      ))'
      if ! PROVISIONED=$(
        command jq --compact-output "$jqprg" --args "${args[@]}"  <<<"$PROVISIONED"
      ); then
        echo "An error occurred while aggregating actions after proviso."
        echo "To replicate, run:"
        echo "jq '$jqprg' --args ${args[@]} <<<[]"
        exit 1
      fi
    fi
    unset -f _proviso
  done
}

echo "::group::📓 Evaluate ..."
eval_fn
echo "::endgroup::"

echo "::group::✨ Find potential targets ..."
echo "${EVAL}" | command jq --raw-output '.[] | "//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::🔎 Check for proviso ..."
provision
echo "::endgroup::"

echo "::group::🌲️ Save work and only proceed with  ..."
echo "${PROVISIONED}" | command jq --raw-output '.[] | "//\(.cell)/\(.block)/\(.name):\(.action)"'
echo "::endgroup::"

echo "::group::📞️ Pass artifacts to the build matrix ..."
{
  json=$(
    command jq --compact-output '
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
  )

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

  if [[ "$SKIP_DRV_EXPORT" == "false" ]]; then
    command mkdir -p "$EVALSTORE_EXPORT"
    for drv in $(command jq --compact-output --raw-output '.[].actionDrv' <<<"$PROVISIONED"); do
       command nix-store --query --requisites "$drv" | command nix-store --stdin --export | command zstd > "$EVALSTORE_EXPORT/$(basename $drv).zst"
    done
  fi
}
echo "::endgroup::"
