# aws_sso_roller

## Overview

The script creates a new SSO OIDC Client for each region it is used in.  Users
will have to auth with SSO via their own browser.  The script then continues
to add every the SSO role assigned to the user in each of the accounts of the
organization.

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

### Using a namespace ini with addtional profile settings

If `NAMESPACE` for example is set to `xyz`, creating a `${HOME}/.aws_sso_roller/xyz.ini`
file, allows you to populate other CLI settings for each profile in that namespace.

eg.
```ini
cli_pager=
region=us-east-1
```

### Example

If run with the following options:

```bash
SSO_START_URL='https://testorg.awsapps.com/start'
SSO_REGION='us-east-1'
NAMESPACE='xyz'
```

The output in the config file for each matching account/role would be:

```config
[profile xyz-accountname-NameOfRole]
sso_start_url = https://testorg.awsapps.com/start
sso_region = us-east-1
sso_role_name = NameOfRole
sso_account_id = 000000000000
```

Testing it you would then run:

```bash
export AWS_PROFILE='xyz-accountname-NameOfRole'
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
