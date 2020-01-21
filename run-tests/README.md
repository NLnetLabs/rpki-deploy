# NLnet Labs rpki-deploy run-tests docker action

This action runs NLnet Labs Krill E2E tests.

## Inputs

### `ssh_key_path`

**Required** The relative path to the SSH private key file inside $GITHUB_WORKSPACE for accessing the deployed Drpolet.

### `do_token`

**Required** A Digital Ocean API token for creating Digital Ocean resources.

### `mode`

**Required** One of: `deploy`, `run-tests` or `undeploy`. `run-tests` includes `deploy`.

## Outputs

None.

## Example usage

uses: nlnetlabs/rpki-deploy/run-tests@master
with:
  ssh_key_path: my_ssh_key
  do_token: e54ea...fc55
  mode: deploy