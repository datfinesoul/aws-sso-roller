# aws_sso_roller

## Overview

Enumerates all of the AWS SSO permission-sets you have access to in your organization, and creates corresponding profiles in your `~/.aws/config` file.

This script creates a reusable SSO OIDC Client for each region it is used in in case of subsequent runs.  (Unless you are running this for multiple organizations, usually only one client is created)

## Helper Alias

After you've successfully run `aws-sso-roller`, and assuming you have [fzf](https://github.com/junegunn/fzf) installed, the following alias is a nice helper for picking SSO profiles once the initial `aws sso login` is completed.

```bash
alias sso='export AWS_PROFILE=$(sed -n "s/\[profile \(.*\)\]/\1/gp" ~/.aws/config | fzf)'
```

## Usage

### Basic
```bash
./aws-sso-roller.bash
# You then prompted with the following and need to supply the <> values
SSO_START_URL []: https://<yourorg>.awsapps.com/start
SSO_REGION [us-east-1]: <region>
NAMESPACE []: <short_prefix>
```

### (Alternative) Using environment variables

You can also skip all the prompts by providing the following environment variables.

(*replace any `< ... >` values*)

```bash
# specifying the env variables disabled the prompts
SSO_START_URL='https://<yourorg>.awsapps.com/start' \
  SSO_REGION='<region>' \
  NAMESPACE='<short_prefix>' \
  ./aws-sso-roller.bash
```

### (Optional) Add additional AWS CLI settings for all profiles

If `NAMESPACE` for example is set to `xyz`, creating a `${HOME}/.aws_sso_roller/xyz.ini` file, allows you to populate other [CLI settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-settings) for each AWS profile in that namespace.

```ini
cli_pager=
region=us-east-1
```

### Example

The values provided here are purely samples, please replace them with values applicable to your AWS organization.

```bash
SSO_START_URL='https://testorg.awsapps.com/start'
SSO_REGION='us-east-1'
NAMESPACE='xyz'
```

The output in the config file for each matching account/role would be:

```config
[profile xyz-account1-role1]
sso_start_url = https://testorg.awsapps.com/start
sso_region = us-east-1
sso_role_name = role1
sso_account_id = 000000000000
```

Testing it you would then run:

```bash
export AWS_PROFILE='xyz-account1-role1'
aws sso login
aws sts get-caller-identity
```

## Config Dir

- The generated client configuration files are stored in `${HOME}/.aws_sso_roller`.
- In addition, cached files (for `DEBUG='on'` mode) would also be stored there.

## Under the hood

This script utilizes:
- [jq](https://github.com/stedolan/jq)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

The following AWS CLI commands are utilized:
- `aws configure set`
- `aws sso-oidc register-client`
- `aws sso-oidc start-device-authorization`
- `aws create-token`
- `aws list-accounts`
- `aws sso list-account-roles`

## Notes

```bash
SSO_START_URL='https://u-io.awsapps.com/start' \
  SSO_REGION='ap-northeast-1' \
  NAMESPACE='io' \
  ./aws-sso-roller.bash [--cache]
```

There is a `--cache` option that can be passed to the script, which uses previously existing AWS authorization and also caches client authorization to re-running the script.  This primarily exists for development and should not be used unless needed.

The reason the OIDC client is cached, is because AWS might ban an IP address that generates too many OIDC clients.
