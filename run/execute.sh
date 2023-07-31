#!/usr/bin/env bash

set -e
set -o pipefail

#shellcheck disable=SC2154
if [[ "$DRV_IMPORT_FROM_DISCOVERY" == "false" ]]; then
   unzstd < "$EVALSTORE_IMPORT/$(basename "$actionDrv").zst" | nix-store --import &>/dev/null
else
   ssh discovery -- "nix-store --query --requisites $actionDrv | nix-store --stdin --export | zstd" \
   | unzstd | nix-store --import &>/dev/null
fi

#shellcheck disable=SC2154
echo "::group::🏗️ build //$cell/$block/$target"

#shellcheck disable=SC2086
build_args=(
  "--no-link"
  "--print-build-logs"
  "--log-format" "raw-with-logs"
  "--eval-store" "auto"
)

if [[ "$REMOTE_STORE" != "false" ]]; then
  build_args+=(
    "--builders" "''"
    "--store" "$REMOTE_STORE"
  )
fi

# Note about: sed $'s/\r\033\[0m\033\[K//g'
#   works around https://discourse.nixos.org/t/nix-with-faketty/31042
start=$(date +%s)
faketty nix build "${build_args[@]}" "$actionDrv^out" \
  1> /dev/null \
  2> >(sed --unbuffered $'
    s/\r\033\[0m\033\[K//g

    # match lines starting with copying
    /copying path .*/ {
      # write them to ./copylogs
      w ./copylogs
      # delete them from the stream
      d
    }
  ' >&2)

echo "Copied $(sed '/copying 0 .*/d' < ./copylogs | wc -l) paths during the build."
end=$(date +%s)
echo -e "\033[0;32mBuilt action closure in $((end-start)) seconds\033[0m"

echo "::endgroup::"

shopt -s lastpipe


#shellcheck disable=SC2154
if [[ "$action" != "build" ]]; then

  out="$(nix derivation show "$actionDrv^out" | jq -r '.[].outputs.out.path')"

  if [[ "$REMOTE_STORE" != "false" ]] && [[ ! -e "$out" ]]; then
    echo "::group::🐟 fetch $action closure (from $REMOTE_STORE)"
    {
      start=$(date +%s)
      nix copy --from "$REMOTE_STORE" "$out" 1> /dev/null 2> >(sed --unbuffered "
  
        # delete some lines that dont make sense
        /^$/d
        /don't know how to.*/d
        \%^\s\s/nix/store/.*%d
  
        # be less noisy - extract store path only
        s/copying path '//g;s/'.*//g;
  
      " >&2)
      end=$(date +%s)
      echo -e "\033[0;32mFetched action closure in $((end-start)) seconds.\033[0m"
    }
    echo "::endgroup::"
  fi

  #shellcheck disable=SC2154
  echo "::group::🏍️️ $action //$cell/$block/$target"
  {
    
    echo -e "\033[1;32m//$cell/$block/$target:$action\033[0m"
    echo -e "\033[1;32m.  $out\033[0m"

    start=$(date +%s)
    # this trick preserves set -e & set -o pipefail from above
    #shellcheck disable=SC1090
    function _run() { . "$out"; }
    _run
    end=$(date +%s)
    echo -e "\033[0;32mRan action in $((end-start)) seconds.\033[0m"
  }
  echo "::endgroup::"
fi
