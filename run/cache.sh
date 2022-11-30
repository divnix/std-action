#!/usr/bin/env bash


echo "::group::Upload to Cache"

printf "%s\n" "::debug::uploading:" "$UNCACHED"

if [[ $CACHE =~ ? ]]; then
  CACHE="$CACHE&secret-key=$NIX_KEY"
else
  CACHE="$CACHE?secret-key=$NIX_KEY"
fi

#shellcheck disable=SC2086
nix copy --from "$BUILDER" --to "$CACHE" $UNCACHED

echo "::endgroup::"
