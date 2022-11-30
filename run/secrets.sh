#!/usr/bin/env bash

AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"

if [[ ! -f $NIX_KEY_PATH && -n $NIX_SECRET_KEY ]]; then
  echo "making nix secret key file..."

  echo "$NIX_SECRET_KEY" >"$NIX_KEY_PATH"

  chmod 0600 "$NIX_KEY_PATH"
fi

if [[ ! -f $AWS_SHARED_CREDENTIALS_FILE && -n $AWS_ACCESS_KEY_ID && -n $AWS_SECRET_ACCESS_KEY ]]; then
  echo "making aws credentials file..."

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
fi
