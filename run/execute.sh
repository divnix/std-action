#!/usr/bin/env bash

set -e
set -o pipefail

#shellcheck disable=SC2154

if [[ "$DRV_IMPORT_FROM_DISCOVERY" == "false" ]]; then
   cat "$EVALSTORE_IMPORT/$(basename $actionDrv).zst" \
   | unzstd | nix-store --import &>/dev/null
else
   ssh discovery -- "nix-store --query --requisites $actionDrv | nix-store --stdin --export | zstd" \
   | unzstd | nix-store --import &>/dev/null
fi

#shellcheck disable=SC2154
echo "::group::🏗️ build //$cell/$block/$target"

#shellcheck disable=SC2086
command nix-build --eval-store auto --store "$BUILDER" "$actionDrv"

echo "::endgroup::"

shopt -s lastpipe

#shellcheck disable=SC2154
if [[ "$action" != "build" ]]; then

  #shellcheck disable=SC2154
  echo "::group::🏍️️ $action //$cell/$block/$target"
  {
    if [[ $BUILDER != auto ]]; then
      command nix copy --from "$BUILDER" "$actionDrv"
    else
      command nix-build "$actionDrv" --no-out-link
    fi

    out="$(command nix derivation show "$actionDrv^*" | command jq -r '.[].outputs.out.path')"
    if [[ ! -e $out ]]; then
      command nix-build "$actionDrv" --no-out-link
    fi

    # this trick preserves set -e & set -o pipefail from above
    #shellcheck disable=SC1090
    function _run() { . "$out"; }
    _run
  }
  echo "::endgroup::"
fi
