#!/usr/bin/env bash

eval_store="$TMPDIR/eval"

# ---------------------------------------------------------------------

echo "::group::Nix Evaluation"

ci_json="$(nix eval .#__std.ci."$(nix eval --raw --impure --expr 'builtins.currentSystem')" --json)"

echo "json=$ci_json" >> "$GITHUB_OUTPUT"

echo "nix_conf=$(nix eval --raw .#__std.nixConfig)" >> "$GITHUB_OUTPUT"

echo "::debug::$ci_json"
echo "::endgroup::"

# ---------------------------------------------------------------------

echo "::group::Archive Eval Store"

#shellcheck disable=SC2046
nix copy \
  --no-check-sigs \
  --derivation \
  --no-auto-optimise-store \
  --to "$eval_store" \
  $(jq -r '.[]|to_entries[]|select(.key|test("Drv$"))|select(.value|.!=null)|.value' <<< "$ci_json")

tar -C "$eval_store" --zstd -f "$TMPDIR/discovery.tar.zstd" -c .

echo "::endgroup::"