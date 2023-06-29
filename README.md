# Standard Action

_for [Standard] & [Paisano]_.

[Paisano]: https://github.com/paisano-nix
[Standard]: https://github.com/divnix/std

Don't waste any time on extra work. Use Standard Action to automatically
detect CI targets that need re-doing; implemented on top of familiar GH Actions.

## Features

- Evaluate once and distribute final build instructions to workers
- Once configured, `discovery` picks up new targets automatically
- Optional `proviso` script can detect if work needs to be done

> **Note on `proviso`**: one example is the oci block type which
> checks if the image is already in the registry and only schedules
> a build if its missing. If `proviso` queries private remote state
> then the `discovery` environment must provide all authentication
> prior to running the discovery step.

## Usage

**Minimumn nix version `v2.16.1`**

- Works with https://github.com/divnix/std
- Since GitHub CI doesn't support yaml anchors, explode your file with: `yq '. | explode(.)' ci.raw.yaml > ci.yaml`

### Standalone

```nix
{
  /* ... */
  outputs = {std, ...}@inputs: std.growOn {
  /* ... */
    cellBlocks = with std.blockTypes; [
      (installables "packages" {ci.build = true;})
      (containers "oci-images" {ci.publish = true;})
      (kubectl "deployments" {ci.apply = true;})
    ];
  /* ... */
  };
}
```

<details><summary><h4>GH Action file</h4></summary>

```yaml
# yq '. | explode(.)' this.yml > .github/workflows/std.yml
name: CI/CD

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

concurrency:
  group: std-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  discover:
    outputs:
      hits: ${{ steps.discovery.outputs.hits }}
    runs-on: ubuntu-latest
    steps:
      # Important: use this as it also detects flake configuration
      - uses: blaggacao/nix-quick-install-action@detect-nix-flakes-config
      # if you want to use nixbuild
      - uses: nixbuild/nixbuild-action@v17
        with:
          nixbuild_ssh_key: ${{ secrets.SSH_PRIVATE_KEY }}
          generate_summary_for: job
      # significantly speeds up things in small projects
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - uses: divnix/std-action/discover@main
        id: discovery

  build: &job
    needs: discover
    name: ${{ matrix.target.jobName }}
    runs-on: ubuntu-latest
    if: fromJSON(needs.discover.outputs.hits).packages.build != '{}'
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).packages.build }}
    steps:
      # Important: use this as it also detects flake configuration
      - uses: blaggacao/nix-quick-install-action@detect-nix-flakes-config
      # if you want to use nixbuild
      - uses: nixbuild/nixbuild-action@v17
        with:
          nixbuild_ssh_key: ${{ secrets.SSH_PRIVATE_KEY }}
          generate_summary_for: job
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - uses: divnix/std-action/run@main

  images:
    <<: *job
    needs: [discover, build]
    if: fromJSON(needs.discover.outputs.hits).oci-images.publish != '{}'
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).oci-images.publish }}

  deploy:
    <<: *job
    needs: [discover, images]
    environment:
      name: development
      url: https://my.dev.example.com
    if: fromJSON(needs.discover.outputs.hits).deployments.apply != '{}'
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).deployments.apply }}
```

</details>

### Persistent Discovery Host

#### Requirements

- `nix` >= v2.16.1
- `zstd`
- (gnu) `parallel`
- `jq`
- `base64`
- `bash` > v5

The persistent host must also implement the `nixConfig` detection capabilities
implemented by [this script][script].

[script]: https://github.com/nixbuild/nix-quick-install-action/blob/5752d21669438be20da4de77327ae963e98c82a3/read-nix-config-from-flake.sh

```nix
{
  /* ... */
  outputs = {std, ...}@inputs: std.growOn {
  /* ... */
    cellBlocks = with std.blockTypes; [
      (devshells "envs" {ci.build = true;})
      (containers "oci-images" {ci.publish = true;})
    ];
  /* ... */
  };
}
```

<details><summary><h4>GH Action file</h4></summary>

```yaml
# yq '. | explode(.)' this.yml > .github/workflows/std.yml
name: CI/CD

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

env:
  DISCOVERY_USER_NAME: gha-runner
  DISCOVERY_KNOWN_HOSTS_ENTRY: "10.10.10.10 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOVVDZydvD+diYa6A3EtA3WGw5NfN0wv7ckQxa/fX1O"

permissions:
  id-token: write
  contents: read

concurrency:
  group: ${{ github.sha }}
  cancel-in-progress: true

jobs:
  discover:
    outputs:
      hits: ${{ steps.discovery.outputs.hits }}
    runs-on: [self-hosted, discovery]
    steps:
      - name: Standard Discovery
        uses: divnix/std-action/discover@main
        id: discovery
        # avoids transporting derivations via GH Cache
        with: { ffBuildInstructions: true }

  image: &run-job
    needs: discover
    strategy:
      fail-fast: false
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).oci-images.publish }}
    if: fromJSON(needs.discover.outputs.hits).oci-images.publish != '{}'
    name: ${{ matrix.target.jobName }}
    runs-on: ubuntu-latest
    steps:
      # sets up ssh credentials for `ssh discovery ...`
      - uses: divnix/std-action/setup-discovery-ssh@main
        with:
          ssh_key: ${{ secrets.SSH_PRIVATE_KEY_CI }}
          user_name: ${{ env.DISCOVERY_USER_NAME }}
          ssh_known_hosts_entry: ${{ env.DISCOVERY_KNOWN_HOSTS_ENTRY }}
      - uses: divnix/std-action/run@main
        # avoids retreiving derivations via GH Cache and uses `ssh discovery ...` instead
        with: { ffBuildInstructions: true }

  build:
    <<: *run-job
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).envs.build }}
    if: fromJSON(needs.discover.outputs.hits).envs.build != '{}'
```

</details>

## Notes & Explanation

### Notes on the Build Matrix

Hits from the discovery phase are namespaced by Block and Action.

That means:

- In: `target: ${{ fromJSON(needs.discover.outputs.hits).packages.build }}`
  - `packages` is the name of a Standard Block
  - `build` is the name of an Action of that Block

### Debugging

Watch out for `base64`-encoded blobs in the logs, you can inspect the
working data of that context by doing: `base64 -d <<< copy-blob-here | jq`.
