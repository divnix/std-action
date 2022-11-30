#!/usr/bin/env bash

action="$(jq .action <<< "$JSON")"

echo "::group::Running $action"

drv="$(jq .actionDrv <<< "$JSON")"

if [[ $BUILDER != auto ]]; then
  nix copy --from "$BUILDER" --to auto "$drv"
fi
eval "$(nix show-derivation "$drv" | jq -r '.[].outputs.out.path')"

echo "::endgroup::"
