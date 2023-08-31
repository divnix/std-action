#!/usr/bin/env bash

set -eu
set -o pipefail

# Setup known_hosts
SSH_KNOWN_HOSTS_FILE="$(mktemp)"
printenv DISCOVERY_SSH_KNOWN_HOSTS_ENTRY > "$SSH_KNOWN_HOSTS_FILE"

host_name="$(echo "$DISCOVERY_SSH_KNOWN_HOSTS_ENTRY" | cut -d ' ' -f 1)"

# Create ssh config
SSH_CONFIG_FILE="$(mktemp)"
cat >"$SSH_CONFIG_FILE" <<EOF
Host discovery
HostName $host_name
User $DISCOVERY_USER_NAME
LogLevel ERROR
StrictHostKeyChecking yes
UserKnownHostsFile $SSH_KNOWN_HOSTS_FILE
ControlPath none
EOF

# Setup auth
ssh_key_file="$(mktemp)"
printenv DISCOVERY_SSH_KEY > "$ssh_key_file"
if ssh-keygen -y -f "$ssh_key_file" &>/dev/null; then
  # Start ssh agent
  eval $(ssh-agent)
  # Add ssh key to agent
  ssh-add -q "$ssh_key_file" && rm "$ssh_key_file"
  # Auth agent socket to ssh config
  echo "IdentityAgent $SSH_AUTH_SOCK" >> "$SSH_CONFIG_FILE"
  # Save pid to cleanup in post step
  echo "SSH_AGENT_PID=$SSH_AGENT_PID" >> "$GITHUB_STATE"
else
  echo -e >&2 \
"Your SSH key is not a valid OpenSSH private key\n"\
"This is likely caused by one of these issues:\n"\
"* The key has been configured incorrectly in your workflow file.\n"\
"* The workflow was triggered by an actor that has no access to\n"\
"  the GitHub Action secret used for storing your SSH key.\n"\
"  For example, Pull Requests originating from a fork of your\n"\
"  repository can't access secrets."
  exit 1
fi

# Append ssh config to system config
sudo mkdir -p /etc/ssh
sudo touch /etc/ssh/ssh_config
sudo tee -a /etc/ssh/ssh_config < "$SSH_CONFIG_FILE" >/dev/null
