# Usage

- Works with https://github.com/divnix/std
- Since GitHub CI doesn't support yaml anchors, explode your file with: `yq '. | explode(.)' ci.raw.yaml > ci.yaml`
- To set up AWS Credentials for an S3 Cache, find details [here](https://github.com/aws-actions/configure-aws-credentials)
- **Warning:** This is still under active development and testing. You're likely better off waiting a little while, still.
  - But it's already being used with success :smile:

```yaml
# .github/workflows/ci.yml
name: Standard CI

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  discover:
    outputs:
      hits: ${{ steps.discovery.outputs.hits }}
      nix_conf: ${{ steps.discovery.outputs.nix_conf }}

    runs-on: ubuntu-latest
    concurrency:
      group: ${{ github.workflow }}
    steps:
      - name: Standard Discovery
        uses: divnix/std-action/discover@main
        id: discovery
        with:
          github_pat: ${{ secrets.HUB_PAT }}

  build-packages: &run-job
    needs: discover
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).packages.build }}
    name: ${{ matrix.target.cell }} - ${{ matrix.target.name }}
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1-node16
        with:
          role-to-assume: arn:aws:iam::123456789100:role/my-github-actions-role
          aws-region: us-east-2
      - uses: divnix/std-action/run@main
        with:
          extra_nix_config: |
            ${{ needs.discover.outputs.nix_conf }}
          json: ${{ toJSON(matrix.target) }}
          # optional:
          github_pat: ${{ secrets.HUB_PAT }}
          nix_key: ${{ secrets.NIX_SECRET_KEY }}
          nix_ssh_key: ${{ secrets.NIXBUILD_SSH }}
          cache: s3://nix?endpoint=sfo3.digitaloceanspaces.com
          builder: ssh-ng://eu.nixbuild.net
          ssh_known_hosts: "eu.nixbuild.net ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM"

  build-devshells:
    <<: *run-job
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).devshells.build }}

  publish-containers:
    <<: *run-job
    strategy:
      matrix:
        target: ${{ fromJSON(needs.discover.outputs.hits).containers.publish }}
```

## Notes & Explanation

### Notes on the Build Matrix

Hits from the discovery phase are namespaced by Block and Action.

That means:

- In: `target: ${{ fromJSON(needs.discover.outputs.hits).packages.build }}`
  - `packages` is the name of a Standard Block
  - `build` is the name of an Action of that Block

This example would be defined in `flake.nix` as such

```nix
{
  /* ... */
  outputs = {std, ...}@inputs: std.growOn {
  /* ... */
    cellBlocks = with std.blockTypes; [
      (installables "packages" {ci.build = true;})
      (containers "containers" {ci.publish = true;})
    ];
  /* ... */
  };
}
```

An example schema of the json returned by the dicovery phase:

```json
{
  "containers": {
    "publish": [
      {
        "action": "publish",
        "actionDrv": "/nix/store/6b0i2ww5drcdfa6hgxijx39zbcq57rwl-publish.drv",
        "actionFragment": "\"__std\".\"actions\".\"x86_64-linux\".\"_automation\".\"containers\".\"vscode\".\"publish",
        "block": "containers",
        "blockType": "containers",
        "cell": "_automation",
        "name": "vscode",
        "targetDrv": "/nix/store/4hs8x5lgb9nkvjfrxj7azv95hi77avxn-image-std-vscode.json.drv",
        "targetFragment": "\"x86_64-linux\".\"_automation\".\"containers\".\"vscode\""
      }
    ]
  },
  "devshells": {
    "build": [
      {
        "action": "build",
        "actionDrv": "/nix/store/zmlva6xlngzj098znyy47p72rxjzgka3-build.drv",
        "actionFragment": "\"__std\".\"actions\".\"x86_64-linux\".\"_automation\".\"devshells\".\"default\".\"build",
        "block": "devshells",
        "blockType": "devshells",
        "cell": "_automation",
        "name": "default",
        "targetDrv": "/nix/store/xq4sl7pf51gp0a036garz56kkr160n5c-Standard.drv",
        "targetFragment": "\"x86_64-linux\".\"_automation\".\"devshells\".\"default\""
      }
    ]
  },
  "packages": {
    "build": [
      {
        "action": "build",
        "actionDrv": "/nix/store/l4y4gzpgym5wbvn42avsaf24nqj0d27y-build.drv",
        "actionFragment": "\"__std\".\"actions\".\"x86_64-linux\".\"std\".\"packages\".\"adrgen\".\"build",
        "block": "packages",
        "blockType": "installables",
        "cell": "std",
        "name": "adrgen",
        "targetDrv": "/nix/store/mwidj7li8b7zypq83ap0fmmwxqx58qn6-adrgen-2022-08-08.drv",
        "targetFragment": "\"x86_64-linux\".\"std\".\"packages\".\"adrgen\""
      }
    ]
  }
}
```
