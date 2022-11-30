#!/usr/bin/env bash

set -e

function mk_nix() {
  echo "::group::Make Nix secret key."

  echo "$NIX_SECRET_KEY" >"$NIX_KEY_PATH"

  chmod 0600 "$NIX_KEY_PATH"

  echo "::endgroup::"
}

function mk_aws() {
  echo "::group::Make S3 credentials file."

  local AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"

  mkdir -p "${AWS_SHARED_CREDENTIALS_FILE%/*}"

  cat <<-EOF >"$AWS_SHARED_CREDENTIALS_FILE"
	[default]
	aws_access_key_id = $AWS_ACCESS_KEY_ID
	aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
	EOF

  sudo mkdir -p ~root/.aws
  sudo cp "$AWS_SHARED_CREDENTIALS_FILE" ~root/.aws/credentials
  sudo chmod 0600 ~root/.aws/credentials

  chmod 0600 "$AWS_SHARED_CREDENTIALS_FILE"

  echo "::endgroup::"
}

if [[ ! -f $NIX_KEY_PATH && -n $NIX_SECRET_KEY ]]; then
  mk_nix
fi

if [[ ! -f $AWS_SHARED_CREDENTIALS_FILE && -n $AWS_ACCESS_KEY_ID && -n $AWS_SECRET_ACCESS_KEY ]]; then
  mk_aws
fi
