#!/usr/bin/env bash

drvs=$(jq -r '.|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$JSON")

# ---------------------------------------------------------------------

echo "::group::Calculate Uncached Builds"

#shellcheck disable=SC2086
mapfile -s 1 -t unbuilt < <(nix-store --realise --dry-run $drvs 2>&1 | sed '/paths will be fetched/,$ d')

printf "%s\n" "::debug::uncached paths:" "${unbuilt[@]}"

echo "uncached=${unbuilt[*]}" >> "$GITHUB_OUTPUT"

echo "::endgroup::"

# ---------------------------------------------------------------------

echo "::group::Nix Build"

#shellcheck disable=SC2086
printf "%s\n" "::debug::these paths will be built:" $drvs

#shellcheck disable=SC2086
nix-store --eval-store auto --store "$BUILDER" --realise $drvs

echo "::endgroup::"
