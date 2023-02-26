# aws_sso_roller

## Overview

The script creates a new SSO OIDC Client for each region it is used in.  Users
will have to auth with SSO via their own browser.  The script then continues
to add every the SSO role assigned to the user in each of the accounts of the
organization.

## Helper Alias

Assuming you have [fzf](https://github.com/junegunn/fzf) installed, the following
alias is a nice helper for picking SSO profiles after this script has run.

```bash
alias sso='export AWS_PROFILE=$(sed -n "s/\[profile \(.*\)\]/\1/gp" ~/.aws/config | fzf)'
```

## Usage

### Basic
```bash
./aws-sso-roller.bash
```

### With pre-populated defaults
```bash
# specifying the env variables disabled the prompts
SSO_START_URL='https://<yourorg>.awsapps.com/start' \
  SSO_REGION='<region>' \
  NAMESPACE='<short_prefix>' \
  ./aws-sso-roller.bash
```

### Using a namespace `.ini` with additional profile settings

If `NAMESPACE` for example is set to `xyz`, creating a `${HOME}/.aws_sso_roller/xyz.ini`
file, allows you to populate other [CLI settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-settings) for each profile in that namespace.

eg.
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

The following AWS CLI commands are used:
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
  ./aws-sso-roller.bash
```
