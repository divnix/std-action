#!/usr/bin/env bash

if [[ $OS == macOS ]]; then
  nix run nixpkgs/nixpkgs-22.11-darwin#bash -- "$SCRIPT"
else
  "$SCRIPT"
fi
