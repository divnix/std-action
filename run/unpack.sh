#!/usr/bin/env bash

eval_store="$TMPDIR/eval"

mkdir -p "$eval_store"

tar -C "$eval_store" --zstd -f "$TMPDIR/discovery.tar.zstd" -x .

if [[ $NIX_KEY_PATH != "" ]]; then
  nix store sign -r -k "$NIX_KEY_PATH" --all --store "$eval_store"
fi

nix copy --all --from "$eval_store" --to auto
