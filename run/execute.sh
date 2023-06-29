#!/usr/bin/env bash

set -e
set -o pipefail

#shellcheck disable=SC2154

if [[ "$DRV_IMPORT_FROM_DISCOVERY" == "false" ]]; then
   cat "$EVALSTORE_IMPORT/$(basename $actionDrv).zst" \
   | unzstd | nix-store --import &>/dev/null
else
   ssh discovery -- 'nix-store --export $(nix-store --query --requisites '$actionDrv') | zstd' \
   | unzstd | nix-store --import &>/dev/null
fi

#shellcheck disable=SC2154
echo "::group::🏗️ build //$cell/$block/$target"

#shellcheck disable=SC2086
command nix-build --eval-store auto "$actionDrv"

echo "::endgroup::"

shopt -s lastpipe

#shellcheck disable=SC2154
if [[ "$action" != "build" ]]; then

  #shellcheck disable=SC2154
  echo "::group::🏍️️ $action //$cell/$block/$target"
  {
    # this trick preserves set -e & set -o pipefail from above
    #shellcheck disable=SC1090
    function _run() { . ./result; }
    _run
  }
  echo "::endgroup::"
fi
